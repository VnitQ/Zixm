; NOTE: Check AVX-512 VALIGN* codegen for the LLVM intrinsics used by
; _mm512_alignr_epi32 / _mm512_alignr_epi64 (via @llvm.x86.avx512.mask.valign.*).
; RUN: llc < %s -mtriple=x86_64-unknown-linux-gnu -mattr=+avx512f | FileCheck %s

target triple = "x86_64-unknown-linux-gnu"

declare <16 x i32> @llvm.x86.avx512.mask.valign.d.512(<16 x i32>, <16 x i32>, i32, <16 x i32>, i16)
declare <8 x i64> @llvm.x86.avx512.mask.valign.q.512(<8 x i64>, <8 x i64>, i32, <8 x i64>, i8)

; Corresponds to _mm512_alignr_epi32(A, B, 3) with full writemask.
define <16 x i32> @test_valignd512_intrinsic(<16 x i32> %a, <16 x i32> %b) nounwind {
; CHECK-LABEL: test_valignd512_intrinsic:
; CHECK:       valignd
; CHECK-NOT:   vpermps
; CHECK-NOT:   vpermi2ps
  %r = call <16 x i32> @llvm.x86.avx512.mask.valign.d.512(<16 x i32> %a, <16 x i32> %b, i32 3, <16 x i32> zeroinitializer, i16 -1)
  ret <16 x i32> %r
}

; Corresponds to _mm512_alignr_epi64(A, B, 2) with full writemask.
define <8 x i64> @test_valignq512_intrinsic(<8 x i64> %a, <8 x i64> %b) nounwind {
; CHECK-LABEL: test_valignq512_intrinsic:
; CHECK:       valignq
; CHECK-NOT:   vpermpd
; CHECK-NOT:   vpermi2pd
  %r = call <8 x i64> @llvm.x86.avx512.mask.valign.q.512(<8 x i64> %a, <8 x i64> %b, i32 2, <8 x i64> zeroinitializer, i8 -1)
  ret <8 x i64> %r
}
