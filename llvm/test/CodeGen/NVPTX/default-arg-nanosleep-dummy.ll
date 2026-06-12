; RUN: opt -S < %s | FileCheck %s
;
; NVVMBuiltin + DefaultAttrsIntrinsic (void-returning).
; Old decl: 1 arg (i32). New: 2 args. Arg[1] = i1, default = false.

declare void @llvm.nvvm.nanosleep.dummy(i32)

define void @test_nanosleep_dummy(i32 %ns) {
entry:
  call void @llvm.nvvm.nanosleep.dummy(i32 %ns)
  ret void
}
; CHECK-LABEL: @test_nanosleep_dummy
; CHECK: call void @llvm.nvvm.nanosleep.dummy(i32 %ns, i1 false)
