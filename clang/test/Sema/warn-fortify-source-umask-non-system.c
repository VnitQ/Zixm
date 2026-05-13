// RUN: %clang_cc1 -triple x86_64-apple-macosx10.14.0 %s -verify
// expected-no-diagnostics

// User-defined umask whose signature spells the typedef `mode_t`
// (matching libc on systems where the prototype isn't written in terms
// of a libc-internal alias), but the declaration is in user code rather
// than a system header. The fortify gate requires a system-header
// origin, so no warning fires.

typedef unsigned mode_t;
extern mode_t umask(mode_t cmask);

void call_user_mode_umask(void) {
  (void)umask(01000);
  (void)umask(0xFFFF);
  (void)umask(7777);
}
