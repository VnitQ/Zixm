; RUN: opt -S < %s | FileCheck %s
;
; Verifies that AutoUpgrade correctly fills in a missing trailing argument
; with the value declared via DefaultValue in the intrinsic's TableGen
; definition.

declare i32 @llvm.nvvm.test.add3(i32, i32, i32)

define i32 @test_default_single_val(i32 %a, i32 %b, i32 %c) {
entry:
  %r = call i32 @llvm.nvvm.test.add3(i32 %a, i32 %b, i32 %c)
  ret i32 %r
}
; CHECK-LABEL: @test_default_single_val
; CHECK: call i32 @llvm.nvvm.test.add3(i32 %a, i32 %b, i32 %c, i32 255)
