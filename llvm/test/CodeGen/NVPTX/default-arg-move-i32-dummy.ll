; RUN: opt -S < %s | FileCheck %s
;
; DefaultAttrsIntrinsic with return type (no NVVMBuiltin).
; Old decl: 1 arg (i32). New: 2 args. Arg[1] = i64, default = 99.

declare i32 @llvm.nvvm.move.i32.dummy(i32)

define i32 @test_move_i32_dummy(i32 %a) {
entry:
  %r = call i32 @llvm.nvvm.move.i32.dummy(i32 %a)
  ret i32 %r
}
; CHECK-LABEL: @test_move_i32_dummy
; CHECK: call i32 @llvm.nvvm.move.i32.dummy(i32 %a, i64 99)
