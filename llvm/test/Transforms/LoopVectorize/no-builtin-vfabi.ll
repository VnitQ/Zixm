; RUN: opt -passes=loop-vectorize -force-vector-width=2 -S < %s | FileCheck %s

; NOTE: This is a focused reproducer for OpenMP declare-simd style VFABI mapping.
; The math libcall is marked no-builtin (as clang emits for declare-simd) and
; memory(none), matching the readnone effects clang gives these libcalls under
; fast-math. LAA must honor the VFABI mapping and vectorize the loop even though
; the scalar callee is no-builtin: a readnone call carries no dependence edge.

define void @test_vector_abi(ptr noalias %x, ptr %c) #0 {
entry:
  br label %loop

loop:
  %iv = phi i64 [ 0, %entry ], [ %iv.next, %loop ]
  %src = getelementptr inbounds double, ptr %c, i64 %iv
  %v = load double, ptr %src, align 8
  %r = tail call double @acosh(double noundef %v) #2
  %dst = getelementptr inbounds double, ptr %x, i64 %iv
  store double %r, ptr %dst, align 8
  %iv.next = add nuw nsw i64 %iv, 1
  %done = icmp eq i64 %iv.next, 1000
  br i1 %done, label %exit, label %loop, !llvm.loop !0

exit:
  ret void
}

; CHECK-LABEL: @test_vector_abi(
; CHECK: vector.body:
; CHECK: call <2 x double> @vector_acosh

declare double @acosh(double noundef) #1

declare <2 x double> @vector_acosh(<2 x double>)

attributes #0 = { noinline nounwind strictfp }
attributes #1 = { nounwind memory(none) "_ZGV_LLVM_N2v_acosh" "no-builtins" "vector-function-abi-variant"="_ZGV_LLVM_N2v_acosh(vector_acosh)" }
attributes #2 = { nobuiltin nounwind strictfp memory(none) "no-builtins" }

!0 = distinct !{!0, !1}
!1 = !{!"llvm.loop.vectorize.enable", i1 true}
