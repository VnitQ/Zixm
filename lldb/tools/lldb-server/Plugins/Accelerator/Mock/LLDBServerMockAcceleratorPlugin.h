//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLDB_TOOLS_LLDB_SERVER_PLUGINS_ACCELERATOR_MOCK_LLDBSERVERMOCKACCELERATORPLUGIN_H
#define LLDB_TOOLS_LLDB_SERVER_PLUGINS_ACCELERATOR_MOCK_LLDBSERVERMOCKACCELERATORPLUGIN_H

#include "Plugins/Process/gdb-remote/LLDBServerAcceleratorPlugin.h"
#include "lldb/Host/MainLoopBase.h"
#include "lldb/Host/common/NativeProcessProtocol.h"

#include <memory>
#include <vector>

namespace lldb_private {

class TCPSocket;

namespace process_gdb_remote {
class GDBRemoteCommunicationServerLLGS;
} // namespace process_gdb_remote

namespace lldb_server {

class LLDBServerMockAcceleratorPlugin : public LLDBServerAcceleratorPlugin {
public:
  LLDBServerMockAcceleratorPlugin(GDBServer &gdb_server, MainLoop &main_loop);
  ~LLDBServerMockAcceleratorPlugin() override;

  llvm::StringRef GetPluginName() override;
  std::optional<AcceleratorActions> GetInitializeActions() override;
  llvm::Expected<AcceleratorBreakpointHitResponse>
  BreakpointWasHit(AcceleratorBreakpointHitArgs &args) override;

private:
  // Start listening for the client's connection to the mock accelerator GDB
  // server and return the connection info the client should connect to.
  std::optional<AcceleratorConnectionInfo> CreateConnection();

  // Breakpoint set during initialization, by function name with no shared
  // library. Requests the "compute" symbol value when hit.
  static constexpr int64_t kBreakpointIDInitialize = 1;
  // Breakpoint set by address, using the "compute" symbol value delivered when
  // the initialize breakpoint was hit.
  static constexpr int64_t kBreakpointIDByAddress = 2;
  // Breakpoint set by function name scoped to a shared library.
  static constexpr int64_t kBreakpointIDByNameShlib = 3;
  // Breakpoint on the dedicated "mock_gpu_accelerator_connect" hook. When hit,
  // the plugin asks the client to create a second target and connect to the
  // mock accelerator GDB server. Only programs that define that function (the
  // connection test) trigger it.
  static constexpr int64_t kBreakpointIDConnect = 4;

  // The in-process GDB server (and its fake process) that serves the mock
  // accelerator connection.
  std::unique_ptr<NativeProcessProtocol::Manager> m_process_manager_up;
  std::unique_ptr<process_gdb_remote::GDBRemoteCommunicationServerLLGS>
      m_gpu_server_up;
  std::unique_ptr<TCPSocket> m_listen_socket;
  std::vector<MainLoopBase::ReadHandleUP> m_read_handles;
};

} // namespace lldb_server
} // namespace lldb_private

#endif // LLDB_TOOLS_LLDB_SERVER_PLUGINS_ACCELERATOR_MOCK_LLDBSERVERMOCKACCELERATORPLUGIN_H
