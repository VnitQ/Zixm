; REQUIRES: arm-registered-target
; RUN: llc -mtriple=armv8a-unknown-linux-gnueabi -verify-machineinstrs < %s -o /dev/null

; This used to assert in RegisterCoalescer after REG_SEQUENCE lowering skipped
; an undef lane even though the REG_SEQUENCE result had a full-register use.

target datalayout = "e-m:e-p:32:32-Fi8-i64:64-v128:64:128-a:0:32-n32-S64"
target triple = "armv8a-unknown-linux-gnueabi"

define void @init(i64 %0, i1 %min.iters.check, ptr %1) {
entry:
  %2 = insertelement <2 x i64> poison, i64 %0, i64 1
  br i1 %min.iters.check, label %common.ret, label %vector.body

common.ret:
  ret void

vector.body:
  %3 = insertelement <2 x i64> %2, i64 1, i64 0
  store <2 x i64> %3, ptr %1, align 8
  br label %common.ret
}
