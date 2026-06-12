; RUN: opt -S < %s | FileCheck %s
;
; Plain Intrinsic<[]> — void-returning, cp_async_bulk style.
; Old decl: 1 arg (i32). New: 2 args. Arg[1] = i1, default = false.

declare void @llvm.nvvm.cp.async.bulk.wait.group.dummy(i32)

define void @test_cp_async_bulk_wait_group_dummy(i32 %n) {
entry:
  call void @llvm.nvvm.cp.async.bulk.wait.group.dummy(i32 %n)
  ret void
}
; CHECK-LABEL: @test_cp_async_bulk_wait_group_dummy
; CHECK: call void @llvm.nvvm.cp.async.bulk.wait.group.dummy(i32 %n, i1 false)
