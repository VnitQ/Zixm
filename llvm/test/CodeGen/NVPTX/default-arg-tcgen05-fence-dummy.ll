; RUN: opt -S < %s | FileCheck %s
;
; Plain Intrinsic<[]>, tcgen05 style.
; Old decl: 2 args (i32, i32). New: 3 args. Arg[2] = i1, default = false.

declare void @llvm.nvvm.tcgen05.fence.dummy(i32, i32)

define void @test_tcgen05_fence_dummy(i32 %flags, i32 %token) {
entry:
  call void @llvm.nvvm.tcgen05.fence.dummy(i32 %flags, i32 %token)
  ret void
}
; CHECK-LABEL: @test_tcgen05_fence_dummy
; CHECK: call void @llvm.nvvm.tcgen05.fence.dummy(i32 %flags, i32 %token, i1 false)
