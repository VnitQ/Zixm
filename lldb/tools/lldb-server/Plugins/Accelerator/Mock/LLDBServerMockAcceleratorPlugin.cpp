//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "LLDBServerMockAcceleratorPlugin.h"
#include "ProcessMockAccelerator.h"

#include "Plugins/Process/gdb-remote/GDBRemoteCommunicationServerLLGS.h"
#include "Plugins/Process/gdb-remote/ProcessGDBRemoteLog.h"
#include "lldb/Host/ProcessLaunchInfo.h"
#include "lldb/Host/Socket.h"
#include "lldb/Host/common/TCPSocket.h"
#include "lldb/Host/posix/ConnectionFileDescriptorPosix.h"
#include "lldb/Utility/Args.h"
#include "lldb/Utility/Connection.h"
#include "lldb/Utility/LLDBLog.h"
#include "lldb/Utility/Log.h"
#include "llvm/Support/FormatVariadic.h"

using namespace lldb;
using namespace lldb_private;
using namespace lldb_private::lldb_server;
using namespace lldb_private::process_gdb_remote;

LLDBServerMockAcceleratorPlugin::LLDBServerMockAcceleratorPlugin(
    GDBServer &gdb_server, MainLoop &main_loop)
    : LLDBServerAcceleratorPlugin(gdb_server, main_loop) {
  // Run a second gdb-remote server inside this lldb-server process (alongside
  // the one debugging the CPU process), backed by ProcessMockAccelerator. No
  // real process is launched or exec'd: ProcessMockAccelerator::Manager just
  // returns a synthetic, already-stopped process with a single thread and a
  // fixed set of registers. The client creates the accelerator target and
  // connects it to this server.
  m_process_manager_up =
      std::make_unique<ProcessMockAccelerator::Manager>(m_main_loop);
  m_gpu_server_up = std::make_unique<GDBRemoteCommunicationServerLLGS>(
      m_main_loop, *m_process_manager_up);

  // LaunchProcess() is how LLGS obtains its current process; it routes to
  // ProcessMockAccelerator::Manager::Launch() (which ignores this info) and
  // only requires a non-empty argument list, so a single placeholder is enough.
  ProcessLaunchInfo info;
  Args args;
  args.AppendArgument("/pretend/path/to/mockgpu");
  info.SetArguments(args, /*first_arg_is_executable=*/true);
  m_gpu_server_up->SetLaunchInfo(info);
  if (Status error = m_gpu_server_up->LaunchProcess(); error.Fail())
    LLDB_LOG(GetLog(GDBRLog::Plugin),
             "failed to create mock accelerator process: {0}",
             error.AsCString());
}

LLDBServerMockAcceleratorPlugin::~LLDBServerMockAcceleratorPlugin() = default;

llvm::StringRef LLDBServerMockAcceleratorPlugin::GetPluginName() {
  return "mock";
}

std::optional<AcceleratorActions>
LLDBServerMockAcceleratorPlugin::GetInitializeActions() {
  AcceleratorActions actions(GetPluginName(), 1);

  // Set a breakpoint by function name (no shared library scope) on the
  // dedicated "mock_gpu_accelerator_initialize" hook and ask for the load
  // address of "mock_gpu_accelerator_compute" to be delivered when it is hit.
  // Using a dedicated, uniquely named function (rather than "main") keeps this
  // mock from affecting other inferiors that lldb-server launches when the
  // plugin is compiled in.
  AcceleratorBreakpointInfo bp;
  bp.identifier = kBreakpointIDInitialize;
  bp.by_name = AcceleratorBreakpointByName{std::nullopt,
                                           "mock_gpu_accelerator_initialize"};
  bp.symbol_names.push_back("mock_gpu_accelerator_compute");
  actions.breakpoints.push_back(std::move(bp));

  return actions;
}

llvm::Expected<AcceleratorBreakpointHitResponse>
LLDBServerMockAcceleratorPlugin::BreakpointWasHit(
    AcceleratorBreakpointHitArgs &args) {
  AcceleratorBreakpointHitResponse response;

  switch (args.breakpoint.identifier) {
  case kBreakpointIDInitialize: {
    // The initialize breakpoint was hit. Disable it, stop the native process,
    // and request more breakpoints: two to exercise the remaining breakpoint
    // types, plus the connection hook now that the accelerator has initialized.
    response.disable_bp = true;
    response.auto_resume_native = false;

    AcceleratorActions actions(GetPluginName(), 2);

    // Breakpoint by function name scoped to a shared library. Tests build to
    // "a.out", so use that as the shared library name.
    AcceleratorBreakpointInfo by_name_shlib;
    by_name_shlib.identifier = kBreakpointIDByNameShlib;
    by_name_shlib.by_name =
        AcceleratorBreakpointByName{"a.out", "mock_gpu_accelerator_finish"};
    actions.breakpoints.push_back(std::move(by_name_shlib));

    // Breakpoint by address, using the "mock_gpu_accelerator_compute" symbol
    // value that was delivered with this breakpoint hit.
    if (std::optional<uint64_t> compute_addr =
            args.GetSymbolValue("mock_gpu_accelerator_compute")) {
      AcceleratorBreakpointInfo by_address;
      by_address.identifier = kBreakpointIDByAddress;
      by_address.by_address = AcceleratorBreakpointByAddress{*compute_addr};
      actions.breakpoints.push_back(std::move(by_address));
    }

    // Now that the accelerator has initialized, set the breakpoint on the
    // dedicated connection hook. Arming it only after the initialize hit
    // (rather than up front) mirrors how a real GPU plugin connects once the
    // runtime is ready. It only resolves in programs that define
    // "mock_gpu_accelerator_connect".
    AcceleratorBreakpointInfo connect_bp;
    connect_bp.identifier = kBreakpointIDConnect;
    connect_bp.by_name = AcceleratorBreakpointByName{
        std::nullopt, "mock_gpu_accelerator_connect"};
    actions.breakpoints.push_back(std::move(connect_bp));

    response.actions = std::move(actions);
    break;
  }
  case kBreakpointIDByAddress:
  case kBreakpointIDByNameShlib:
    // Disable and stop the native process so the hit is observable.
    response.disable_bp = true;
    response.auto_resume_native = false;
    break;
  case kBreakpointIDConnect: {
    // The program reached its connection hook. Ask the client to create a
    // second target and connect to our in-process mock accelerator GDB
    // server.
    response.disable_bp = true;
    response.auto_resume_native = false;
    AcceleratorActions actions(GetPluginName(), kBreakpointIDConnect);
    actions.session_name = "Mock Accelerator Session";
    actions.connect_info = CreateConnection();
    response.actions = std::move(actions);
    break;
  }
  }

  return response;
}

std::optional<AcceleratorConnectionInfo>
LLDBServerMockAcceleratorPlugin::CreateConnection() {
  Log *log = GetLog(GDBRLog::Plugin);

  // Listen on an ephemeral local port; the client will connect to it.
  llvm::Expected<std::unique_ptr<TCPSocket>> sock =
      Socket::TcpListen("localhost:0");
  if (!sock) {
    LLDB_LOG_ERROR(log, sock.takeError(),
                   "mock accelerator failed to listen: {0}");
    return std::nullopt;
  }

  AcceleratorConnectionInfo info;
  info.connect_url =
      llvm::formatv("connect://localhost:{0}", (*sock)->GetLocalPortNumber());
  info.synchronous = true;

  m_listen_socket = std::move(*sock);
  llvm::Expected<std::vector<MainLoopBase::ReadHandleUP>> handles =
      m_listen_socket->Accept(
          m_main_loop, [this](std::unique_ptr<Socket> socket) {
            std::unique_ptr<Connection> connection_up =
                std::make_unique<ConnectionFileDescriptor>(std::move(socket));
            m_gpu_server_up->InitializeConnection(std::move(connection_up));
          });
  if (!handles) {
    LLDB_LOG_ERROR(log, handles.takeError(),
                   "mock accelerator failed to accept: {0}");
    return std::nullopt;
  }
  m_read_handles = std::move(*handles);

  return info;
}
