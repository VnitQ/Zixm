; RUN: opt -S < %s | FileCheck %s
;
; The 4-arg call passes an explicit value. It must be preserved.

declare i32 @llvm.nvvm.test.add3(i32, i32, i32, i32)

define i32 @test_explicit_value_preserved(i32 %a, i32 %b, i32 %c) {
entry:
  %r = call i32 @llvm.nvvm.test.add3(i32 %a, i32 %b, i32 %c, i32 42)
  ret i32 %r
}
; CHECK-LABEL: @test_explicit_value_preserved
; CHECK: call i32 @llvm.nvvm.test.add3(i32 %a, i32 %b, i32 %c, i32 42)
