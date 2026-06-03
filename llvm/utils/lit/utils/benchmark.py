"""
Platform assumptions:
  Linux - x86-64, Intel CPU, clang+lld, sudo; use --skip-env-setup if unsupported
  macOS - Apple Silicon (arm64), caffeinate
  Windows - x86-64 MSVC, x64 Native Tools prompt, env setup requires Administrator
"""

import argparse
import logging
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from platform import system
from typing import Dict, List, Optional, Tuple

SYSTEM = system()
IS_LINUX = SYSTEM == "Linux"
IS_MAC = SYSTEM == "Darwin"
IS_WINDOWS = SYSTEM == "Windows"

log = logging.getLogger("benchmark")


class _LevelFormatter(logging.Formatter):
    """Plain message for INFO (status banners); WARN: prefix for warnings."""

    def format(self, record: logging.LogRecord) -> str:
        msg = record.getMessage()
        return f"WARN: {msg}" if record.levelno >= logging.WARNING else msg


def _configure_logging() -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(_LevelFormatter())
    logging.basicConfig(level=logging.INFO, handlers=[handler])


# Windows power setting GUIDs for CPU boost mode
W_SUB_PROC = "54533251-82be-4824-96c1-47b60b740d00"
W_BOOST = "be337238-0d82-4146-a960-4f3749d470c7"


def _sudo_write(path: Path, value: str) -> None:
    """Write value to sysfs path via sudo tee and suppressing echo"""
    subprocess.run(
        ["sudo", "tee", str(path)],
        input=value,
        text=True,
        check=True,
        stdout=subprocess.DEVNULL,
    )


def _is_windows_admin() -> bool:
    if not IS_WINDOWS:
        return False
    try:
        import ctypes

        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


CGROUP_V2_HINT = """\
cset shield failed (likely cgroup v2); falling back to taskset.
    cgroup v1 cpuset workarounds: https://documentation.ubuntu.com/real-time/latest/how-to/isolate-workload-cpusets/
    Suppress this warning with --disable-cset."""


def _print_cgroup_v2_hint() -> None:
    """Warn that cset needs cgroup v1 and that we fell back to taskset."""
    log.warning(CGROUP_V2_HINT)


class Platform:
    """
    Per-OS benchmark environment manager and command runner.
    """

    def __init__(self, skip_env: bool = False) -> None:
        self.skip_env = skip_env

    def __enter__(self) -> "Platform":
        if self.skip_env:
            return self
        try:
            self.setup()
        except BaseException:
            self.restore()
            raise
        return self

    def __exit__(self, *_) -> None:
        if not self.skip_env:
            self.restore()

    def setup(self) -> None:
        pass

    def restore(self) -> None:
        pass

    def run(
        self,
        lit: Path,
        test_path: Path,
        workers: int,
        warmup: int,
        runs: int,
        results_file: Path,
    ) -> None:
        cmd_str = self.lit_cmd_str(lit, test_path, workers)
        hyp = self.build_hyperfine_cmd(cmd_str, warmup, runs, results_file)
        log.info(f"=== Benchmarking: {test_path} (j{workers}) ===")
        self._launch(hyp)

    def _launch(self, hyp: list) -> None:
        subprocess.run(self.wrap_command(hyp), check=True)

    def build_hyperfine_cmd(
        self, cmd_str: str, warmup: int, runs: int, results_file: Path
    ) -> list:
        return [
            "hyperfine",
            "--ignore-failure",
            "--warmup",
            str(warmup),
            "--runs",
            str(runs),
            "--export-json",
            str(results_file),
            cmd_str,
        ]

    def lit_cmd_str(self, lit: Path, test_path: Path, workers: int) -> str:
        return f"'{lit}' '{test_path}' -j{workers} --no-progress-bar"

    def wrap_command(self, cmd: list) -> list:
        return cmd


class LinuxPlatform(Platform):
    """
    Limitations: Intel CPU only for turbo (AMD boost at cpufreq/boost is TODO);
    requires cpupower and sudo; cset optional. If cset shielding fails at setup
    the run falls back to taskset; that decision lives in self.use_cset.
    """

    GOV_PATH = Path("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")
    TURBO_PATH = Path("/sys/devices/system/cpu/intel_pstate/no_turbo")
    SMT_PATH = Path("/sys/devices/system/cpu/smt/control")
    ASLR_PATH = Path("/proc/sys/kernel/randomize_va_space")

    def __init__(
        self,
        benchmark_cpus: str,
        use_cset: bool,
        cset_available: bool,
        skip_env: bool = False,
    ) -> None:
        super().__init__(skip_env)
        self.benchmark_cpus = benchmark_cpus
        self.saved: Dict[str, str] = {}
        self.use_cset = use_cset
        self.cset_available = cset_available

    def setup(self) -> None:
        self.set_cpu_performance()
        self.disable_turbo()
        self.shield_cpus()
        self.disable_smt()
        self.disable_aslr()

    def restore(self) -> None:
        self.restore_smt()
        self.unshield_cpus()
        self.restore_turbo()
        self.restore_cpu_performance()
        self.restore_aslr()

    def sysfs_set(self, key: str, path: Path, value: str) -> None:
        if not path.exists():
            log.warning(f"could not write {path}")
            return
        self.saved[key] = path.read_text().strip()
        try:
            _sudo_write(path, value)
            log.info(f"=== {key} Disabled ===")
        except subprocess.CalledProcessError:
            log.warning(f"could not write {path}")

    def sysfs_restore(self, key: str, path: Path) -> None:
        if path.exists() and key in self.saved:
            try:
                _sudo_write(path, self.saved[key])
                log.info(f"=== {key} Restored ===")
            except subprocess.CalledProcessError:
                log.warning(f"could not restore {path}")

    def set_cpu_performance(self) -> None:
        if self.GOV_PATH.exists():
            self.saved["governor"] = self.GOV_PATH.read_text().strip()
        try:
            subprocess.run(
                ["sudo", "cpupower", "frequency-set", "-g", "performance"], check=True
            )
        except subprocess.CalledProcessError:
            log.warning("could not set cpu power")

    def restore_cpu_performance(self) -> None:
        try:
            subprocess.run(
                [
                    "sudo",
                    "cpupower",
                    "frequency-set",
                    "-g",
                    self.saved.get("governor", "powersave"),
                ],
                check=False,
            )
        except subprocess.CalledProcessError:
            log.warning("could not restore cpu power")

    def disable_turbo(self) -> None:
        # TODO: disable boost mode for AMD also
        # Skipping for now, as we currently don't have access to AMD CPU
        # https://www.kernel.org/doc/html/latest/admin-guide/pm/cpufreq.html#the-boost-file-in-sysfs
        self.sysfs_set("turbo", self.TURBO_PATH, "1")

    def restore_turbo(self) -> None:
        # TODO: restore boost mode for AMD here
        self.sysfs_restore("turbo", self.TURBO_PATH)

    def disable_smt(self) -> None:
        if self.SMT_PATH.exists() and self.SMT_PATH.read_text().strip() == "on":
            self.sysfs_set("smt", self.SMT_PATH, "off")

    def restore_smt(self) -> None:
        self.sysfs_restore("smt", self.SMT_PATH)

    def disable_aslr(self) -> None:
        self.sysfs_set("aslr", self.ASLR_PATH, "0")

    def restore_aslr(self) -> None:
        self.sysfs_restore("aslr", self.ASLR_PATH)

    def shield_cpus(self) -> None:
        if not self.use_cset or not self.cset_available:
            return
        result = subprocess.run(
            ["sudo", "cset", "shield", "-c", self.benchmark_cpus, "-k", "on"],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            stderr = result.stderr + result.stdout
            if any(
                msg in stderr
                for msg in (
                    "mount of cpuset filesystem failed",
                    "Invalid argument",
                    "failed to create shield",
                    "cpuset not mounted",
                )
            ):
                _print_cgroup_v2_hint()
            else:
                log.warning(f"cset shield failed: {stderr.strip()}")
            self.use_cset = False
        else:
            log.info(f"=== cset shield on CPUs {self.benchmark_cpus} ===")

    def unshield_cpus(self) -> None:
        if self.use_cset and self.cset_available:
            subprocess.run(["sudo", "cset", "shield", "--reset"], check=False)
            log.info("=== cset shield removed ===")

    def wrap_command(self, cmd: list) -> list:
        if self.use_cset:
            return ["sudo", "cset", "shield", "--exec", "--"] + cmd
        return ["sudo", "nice", "-n", "-20", "taskset", "-c", self.benchmark_cpus] + cmd


class MacPlatform(Platform):
    """macOS: caffeinate only. No scriptable turbo/SMT/ASLR/shielding equivalents.

    The run is unwrapped (inherits base lit_cmd_str/wrap_command).
    """

    def __init__(self, skip_env: bool = False) -> None:
        super().__init__(skip_env)
        self.proc: Optional[subprocess.Popen] = None

    def setup(self) -> None:
        self.proc = subprocess.Popen(["caffeinate", "-dimsu"])
        log.info("=== Mac env: caffeinate started ===")

    def restore(self) -> None:
        if self.proc is not None:
            self.proc.terminate()
            self.proc.wait()
            log.info("=== Mac env: caffeinate stopped ===")


class WindowsPlatform(Platform):
    """
    The run is launched HIGH_PRIORITY with a kernel32 affinity mask.
    """

    THROTTLE = [
        ("SUB_PROCESSOR", "PROCTHROTTLEMIN"),
        ("SUB_PROCESSOR", "PROCTHROTTLEMAX"),
        ("SUB_PROCESSOR", "CPMINCORES"),
    ]

    # The plan the benchmark runs under (High Performance).
    BENCH_SCHEME = "SCHEME_MIN"

    def __init__(
        self, repo_root: Path, affinity_mask: str = "FFF", skip_env: bool = False
    ) -> None:
        super().__init__(skip_env)
        self.winmm = None
        self.repo_root = repo_root
        self.affinity_mask = int(affinity_mask, 16)
        self.saved_scheme: Optional[str] = None
        self.saved: Dict[str, Dict[str, str]] = {}

    def setup(self) -> None:
        self.set_cpu_performance()
        self.disable_turbo()
        self.exclude_from_defender()

    def restore(self) -> None:
        self.restore_defender()
        self.restore_turbo()
        self.restore_cpu_performance()

    def _activate_scheme(self, scheme: str) -> subprocess.CompletedProcess:
        """Make a power scheme live. Re-activating the current scheme is how
        pending /set*valueindex changes get pushed to hardware."""
        return subprocess.run(
            ["powercfg", "/setactive", scheme],
            capture_output=True,
            text=True,
            check=False,
        )

    def exclude_from_defender(self) -> None:
        try:
            subprocess.run(
                [
                    "powershell",
                    "-Command",
                    f"Add-MpPreference -ExclusionPath '{self.repo_root}'",
                ],
                check=True,
            )
        except subprocess.CalledProcessError as e:
            log.warning(f"could not add Defender exclusion: {e}")

    def restore_defender(self) -> None:
        if not _is_windows_admin():
            return
        try:
            subprocess.run(
                [
                    "powershell",
                    "-Command",
                    f"Remove-MpPreference -ExclusionPath '{self.repo_root}'",
                ],
                check=True,
            )
        except subprocess.CalledProcessError as e:
            log.warning(f"could not remove Defender exclusion: {e}")

    def query_setting(self, sub: str, setting: str) -> Dict[str, str]:
        r = subprocess.run(
            ["powercfg", "/query", self.BENCH_SCHEME, sub, setting],
            capture_output=True,
            text=True,
        )
        result: Dict[str, str] = {}
        for line in r.stdout.splitlines():
            if "Current AC Power Setting Index:" in line:
                result["ac"] = str(int(line.split(":")[-1].strip(), 16))
            elif "Current DC Power Setting Index:" in line:
                result["dc"] = str(int(line.split(":")[-1].strip(), 16))
        return result

    def apply_setting(self, sub: str, setting: str, val: str) -> None:
        for flag in ("/setacvalueindex", "/setdcvalueindex"):
            try:
                subprocess.run(
                    ["powercfg", flag, self.BENCH_SCHEME, sub, setting, val], check=True
                )
            except subprocess.CalledProcessError as e:
                log.warning(f"{e}")

    def restore_setting(self, key: str, sub: str, setting: str) -> None:
        saved = self.saved.get(key, {})
        for flag, idx in (("/setacvalueindex", "ac"), ("/setdcvalueindex", "dc")):
            if idx in saved:
                subprocess.run(
                    ["powercfg", flag, self.BENCH_SCHEME, sub, setting, saved[idx]],
                    capture_output=True,
                )

    def set_cpu_performance(self) -> None:
        if not _is_windows_admin():
            log.warning("not Administrator; environment setup may partially fail")
        r = subprocess.run(
            ["powercfg", "/getactivescheme"], capture_output=True, text=True
        )
        parts = r.stdout.split()
        if len(parts) >= 4:
            self.saved_scheme = parts[3]
        for sub, setting in self.THROTTLE:
            self.saved[setting] = self.query_setting(sub, setting)
        for sub, setting in self.THROTTLE:
            self.apply_setting(sub, setting, "100")
        r = self._activate_scheme(self.BENCH_SCHEME)
        if r.returncode != 0:
            log.warning(f"could not activate High Performance plan: {r.stderr.strip()}")
            log.warning("benchmark may run under the previous plan")
        try:
            import ctypes

            self.winmm = ctypes.WinDLL("winmm")
            self.winmm.timeBeginPeriod(1)
        except Exception as e:
            log.warning(f"could not set 1 ms timer resolution: {e}")

    def restore_cpu_performance(self) -> None:
        for sub, setting in self.THROTTLE:
            self.restore_setting(setting, sub, setting)
        self._activate_scheme(self.saved_scheme or "SCHEME_BALANCED")
        if self.winmm:
            try:
                self.winmm.timeEndPeriod(1)
            except Exception:
                pass

    def disable_turbo(self) -> None:
        self.saved["boost"] = self.query_setting(W_SUB_PROC, W_BOOST)
        self.apply_setting(W_SUB_PROC, W_BOOST, "0")
        self._activate_scheme("SCHEME_CURRENT")

    def restore_turbo(self) -> None:
        self.restore_setting("boost", W_SUB_PROC, W_BOOST)
        self._activate_scheme("SCHEME_CURRENT")

    def _launch(self, hyp: list) -> None:
        import ctypes

        kernel32 = ctypes.windll.kernel32
        HIGH_PRIORITY_CLASS = 0x00000080
        PROCESS_SET_INFORMATION = 0x0200
        proc = subprocess.Popen(hyp, creationflags=HIGH_PRIORITY_CLASS)
        h = kernel32.OpenProcess(PROCESS_SET_INFORMATION, False, proc.pid)
        if h:
            try:
                if not kernel32.SetProcessAffinityMask(
                    h, ctypes.c_size_t(self.affinity_mask)
                ):
                    log.warning(
                        f"SetProcessAffinityMask failed (err={ctypes.GetLastError()})"
                    )
            finally:
                kernel32.CloseHandle(h)
        else:
            log.warning(
                f"OpenProcess failed (err={ctypes.GetLastError()}); affinity not set"
            )
        proc.wait()
        if proc.returncode != 0:
            raise subprocess.CalledProcessError(proc.returncode, hyp)

    def lit_cmd_str(self, lit: Path, test_path: Path, workers: int) -> str:
        return f'python "{lit}" "{test_path}" -j{workers} --no-progress-bar'


def make_platform(args, repo_root: Path) -> Platform:
    """Detect the OS once and build the matching Platform."""
    skip = args.skip_env_setup
    if IS_LINUX:
        cset_available = bool(shutil.which("cset"))
        use_cset = cset_available and not args.disable_cset and not skip
        if cset_available and not use_cset:
            log.info("cset available but disabled; using taskset")
        elif not cset_available:
            log.warning(
                "cset not found; using taskset (install: sudo apt install cpuset)"
            )
        return LinuxPlatform(args.benchmark_cpus, use_cset, cset_available, skip)
    if IS_MAC:
        return MacPlatform(skip)
    if IS_WINDOWS:
        return WindowsPlatform(repo_root, args.affinity_mask, skip)
    return Platform(skip)


def _check_tools() -> List[str]:
    """Return required tools that are missing (empty list = all present)."""
    return [t for t in ["hyperfine"] if not shutil.which(t)]


def _os_defaults() -> Tuple[int, int]:
    """(warmup, runs)"""
    return 5, 10


def main() -> None:
    _configure_logging()
    default_warmup, default_runs = _os_defaults()
    parser = argparse.ArgumentParser(
        description="lit benchmarking script",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""\
Examples:
  python benchmark.py --test-path llvm-project/llvm/test/CodeGen/X86 --repo-root . --lit build/bin/llvm-lit --workers 4
  python benchmark.py --test-path llvm-project/llvm/test/CodeGen/X86 --repo-root . --lit build/bin/llvm-lit --workers 4 --label baseline

Notes:
  Linux env setup needs cpupower + sudo and assumes an Intel CPU (turbo); cset optional.
  Use --skip-env-setup if those are unavailable and isolate manually.
  On cgroup v2 systems pass --disable-cset if cset fails.

Platform: {SYSTEM} Defaults: --warmup {default_warmup} --runs {default_runs}""",
    )
    parser.add_argument(
        "--test-path",
        required=True,
        metavar="PATH",
        help="Lit test directory, relative to --repo-root",
    )
    parser.add_argument(
        "--repo-root",
        required=True,
        metavar="PATH",
        help="Repo root; parent directory of llvm-project/",
    )
    parser.add_argument(
        "--lit",
        required=True,
        metavar="PATH",
        help="Path to the built lit binary (e.g. build/bin/llvm-lit)",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=4,
        metavar="N",
        help="Parallel lit workers (default: 4)",
    )
    parser.add_argument(
        "--label",
        default="run",
        metavar="STR",
        help="Results directory suffix (default: run)",
    )
    parser.add_argument(
        "--warmup",
        type=int,
        default=default_warmup,
        metavar="N",
        help=f"Hyperfine warmup runs (default: {default_warmup})",
    )
    parser.add_argument(
        "--runs",
        type=int,
        default=default_runs,
        metavar="N",
        help=f"Hyperfine benchmark runs (default: {default_runs})",
    )
    parser.add_argument(
        "--skip-env-setup", action="store_true", help="Skip CPU/service isolation"
    )
    parser.add_argument(
        "--benchmark-cpus",
        default="2,4,6,8",
        metavar="RANGE",
        help="Linux: CPU range for taskset/cset shield (default: '2,4,6,8')",
    )
    parser.add_argument(
        "--affinity-mask",
        default="FFF",
        metavar="HEX",
        help="Windows: CPU affinity mask in hex (default: 'FFF' = P-cores 0-11)",
    )
    parser.add_argument(
        "--disable-cset",
        action="store_true",
        help=(
            "Linux: skip cset/cpuset shielding even if cset is installed; "
            "use taskset instead. Use this on cgroup v2 systems (Ubuntu 22.04+, "
            "Fedora 31+) where cset fails with 'mount of cpuset filesystem failed' "
            "or 'Invalid argument'"
        ),
    )
    args = parser.parse_args()
    repo_root = Path(args.repo_root).resolve()
    lit = repo_root / args.lit
    test_path = repo_root / args.test_path
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    results_dir = repo_root / "results" / f"{args.label}-{timestamp}"
    missing_tools = _check_tools()
    if missing_tools:
        sys.exit(f"ERROR: missing required tools: {', '.join(missing_tools)}")
    if not lit.exists():
        sys.exit(f"ERROR: lit binary not found at {lit}. Check --lit.")
    results_dir.mkdir(parents=True, exist_ok=True)
    with make_platform(args, repo_root) as platform:
        platform.run(
            lit,
            test_path,
            args.workers,
            args.warmup,
            args.runs,
            results_dir / "hyperfine.json",
        )
    log.info("\n=== Done ===")
    log.info(f"Results: {results_dir}")
    for f in sorted(results_dir.iterdir()):
        log.info(f"\t{f.name}")


if __name__ == "__main__":
    main()
