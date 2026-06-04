; NOTE: Float-domain shufflevector masks that match @llvm.x86.avx512.mask.valign.*
; (same shuffle Clang emits for __builtin_ia32_alignd512 / alignq512). After
; InstCombine may keep these as v16f32 / v8f64 shuffles; the backend should
; still select VALIGND / VALIGNQ instead of VPERMPS / VPERMPD.
; RUN: llc < %s -mtriple=x86_64-unknown-linux-gnu -mattr=+avx512f | FileCheck %s

target triple = "x86_64-unknown-linux-gnu"

; shufflevector(B, A, <3..18>) — __builtin_ia32_alignd512(A, B, 3) lowering.
define <16 x float> @test_valignd_v16f32_shuffle(<16 x float> %a, <16 x float> %b) nounwind {
; CHECK-LABEL: test_valignd_v16f32_shuffle:
; CHECK:       valignd
; CHECK-NOT:   vpermps
; CHECK-NOT:   vpermi2ps
  %r = shufflevector <16 x float> %b, <16 x float> %a,
        <16 x i32><i32 3, i32 4, i32 5, i32 6, i32 7, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15, i32 16, i32 17, i32 18>
  ret <16 x float> %r
}

; shufflevector(B, A, <2..9>) — __builtin_ia32_alignq512(A, B, 2) lowering.
define <8 x double> @test_valignq_v8f64_shuffle(<8 x double> %a, <8 x double> %b) nounwind {
; CHECK-LABEL: test_valignq_v8f64_shuffle:
; CHECK:       valignq
; CHECK-NOT:   vpermpd
; CHECK-NOT:   vpermi2pd
  %r = shufflevector <8 x double> %b, <8 x double> %a,
        <8 x i32><i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8, i32 9>
  ret <8 x double> %r
}
