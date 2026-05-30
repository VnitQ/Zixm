; RUN: llc -mtriple=riscv64 -verify-machineinstrs -global-isel -global-isel-abort=2 -pass-remarks-missed='gisel*' %s -o - 2>&1 | FileCheck %s

; An inline asm input value that maps to fewer virtual registers than the
; constraint needs physical registers (here an i128 in a GPR pair via the "R"
; constraint) isn't supported by GlobalISel yet. Check that it falls back
; cleanly instead of crashing in InlineAsmLowering.

define i128 @inline_asm_R_i128(i128 %x) nounwind {
; CHECK: remark: {{.*}} unable to translate instruction: call
; CHECK-LABEL: warning: Instruction selection used fallback path for inline_asm_R_i128
  %r = call i128 asm sideeffect "/* $0 $1 */", "=&R,R"(i128 %x)
  ret i128 %r
}
