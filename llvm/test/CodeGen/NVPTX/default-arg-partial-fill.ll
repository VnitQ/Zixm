; RUN: opt -S < %s | FileCheck %s
;
; Old decl has 5 args (index 5 missing). Arg[4] passed explicitly (i64 99),
; must NOT be overridden. Arg[5] filled with default i32 14.

declare i32 @llvm.nvvm.test.add4(i32, i32, i32, i32, i64)

define i32 @test_partial_fill(i32 %a, i32 %b, i32 %c, i32 %d) {
entry:
  %r = call i32 @llvm.nvvm.test.add4(i32 %a, i32 %b, i32 %c, i32 %d, i64 99)
  ret i32 %r
}
; CHECK-LABEL: @test_partial_fill
; CHECK: call i32 @llvm.nvvm.test.add4(i32 %a, i32 %b, i32 %c, i32 %d, i64 99, i32 14)
