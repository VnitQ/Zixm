; RUN: opt -S < %s | FileCheck %s
;
; test_add4 has 6 params; last two have defaults (i64 50, i32 14).
; Old declaration has only 4 args; both missing defaults are inserted.

declare i32 @llvm.nvvm.test.add4(i32, i32, i32, i32)

define i32 @test_multiple_trailing_defaults(i32 %a, i32 %b, i32 %c, i32 %d) {
entry:
  %r = call i32 @llvm.nvvm.test.add4(i32 %a, i32 %b, i32 %c, i32 %d)
  ret i32 %r
}
; CHECK-LABEL: @test_multiple_trailing_defaults
; CHECK: call i32 @llvm.nvvm.test.add4(i32 %a, i32 %b, i32 %c, i32 %d, i64 50, i32 14)
