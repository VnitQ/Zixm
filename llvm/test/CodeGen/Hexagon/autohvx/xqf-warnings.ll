; XFAIL: hexagon-registered-target
; Tests for emitted warnings when IEEE type is used as qf and vice-versa
; Test program source code with line number:

;1 #include <hexagon_types.h>
;2 HEXAGON_Vect2048 foo(HEXAGON_Vect1024 vina, HEXAGON_Vect1024 vinb) {
;3   const HEXAGON_Vect1024 ishf1 = __builtin_HEXAGON_V6_lvsplath_128B(0x3C00);
;4   const HEXAGON_Vect1024 ishf2 = __builtin_HEXAGON_V6_lvsplath_128B(0xBC00);
;5   const HEXAGON_Vect1024 issf1 = __builtin_HEXAGON_V6_lvsplatw_128B(0xAC00);
;6   const HEXAGON_Vect1024 issf2 = __builtin_HEXAGON_V6_lvsplatw_128B(0xDC00);
;7   const HEXAGON_Vect1024 isqf16 = __builtin_HEXAGON_V6_vadd_qf16_mix_128B(ishf1, ishf2);
;8   const HEXAGON_Vect1024 isqf32 = __builtin_HEXAGON_V6_vadd_qf32_mix_128B(issf1, issf2);
;9   HEXAGON_Vect2048 isqf32_1 = __builtin_HEXAGON_V6_vmpy_qf32_qf16_128B(vina,isqf16);
;10   HEXAGON_Vect2048 isqf32_2 = __builtin_HEXAGON_V6_vmpy_qf32_hf_128B(vinb,isqf16);
;11   HEXAGON_Vect1024 add1 = __builtin_HEXAGON_V6_vsub_qf32_mix_128B(__builtin_HEXAGON_V6_hi_128B(isqf32_1),isqf32);
;12   HEXAGON_Vect1024 add2 = __builtin_HEXAGON_V6_vsub_qf32_128B(__builtin_HEXAGON_V6_hi_128B(isqf32_2),isqf32);
;13   return __builtin_HEXAGON_V6_vcombine_128B(add2,add1);
;14 }

; RUN: llc --mtriple=hexagon-- -mhvx -mcpu=hexagonv79 -mattr=+hvxv79,+hvx-length128b,+hvx-qfloat -enable-xqf-gen=true \
; RUN: -verify-machineinstrs \
; RUN: -hexagon-qfloat-mode=ieee 2>&1 < %s -o /dev/null | FileCheck %s
; RUN: llc --mtriple=hexagon-- -mhvx -mcpu=hexagonv81 -mattr=+hvxv81,+hvx-length128b,+hvx-qfloat -enable-xqf-gen=true \
; RUN: -verify-machineinstrs \
; RUN: -hexagon-qfloat-mode=ieee 2>&1 < %s -o /dev/null | FileCheck %s

define dso_local inreg <64 x i32> @foo(<32 x i32> noundef %vina, <32 x i32> noundef %vinb) local_unnamed_addr #0 !dbg !8 {
; CHECK-NOT: warning: test.c:3:
; CHECK-NOT: warning: test.c:4:
; CHECK-NOT: warning: test.c:5:
; CHECK-NOT: warning: test.c:6:
; CHECK: warning: test.c:7:35: in function foo <64 x i32> (<32 x i32>, <32 x i32>): hf type used as qf16 at operand 1
; CHECK: warning: test.c:8:35: in function foo <64 x i32> (<32 x i32>, <32 x i32>): sf type used as qf32 at operand 1
; CHECK: warning: test.c:9:31: in function foo <64 x i32> (<32 x i32>, <32 x i32>): hf type used as qf16 at operand 1
; CHECK: warning: test.c:10:31: in function foo <64 x i32> (<32 x i32>, <32 x i32>): qf16 type used as hf at operand 2
; CHECK: warning: test.c:11:67: in function foo <64 x i32> (<32 x i32>, <32 x i32>): qf32 type used as sf at operand 1
; CHECK: warning: test.c:11:27: in function foo <64 x i32> (<32 x i32>, <32 x i32>): sf type used as qf32 at operand 1
; CHECK: warning: test.c:11:27: in function foo <64 x i32> (<32 x i32>, <32 x i32>): qf32 type used as sf at operand 2
; CHECK: warning: test.c:12:63: in function foo <64 x i32> (<32 x i32>, <32 x i32>): qf32 type used as sf at operand 1
; CHECK: warning: test.c:12:27: in function foo <64 x i32> (<32 x i32>, <32 x i32>): sf type used as qf32 at operand 1
; CHECK-NOT: warning: test.c:12: {{.*}}: qf32 type used as sf at operand 2
; CHECK-NOT: warning: test.c:12: {{.*}}: sf type used as qf32 at operand 2
; CHECK: warning: test.c:13:10: in function foo <64 x i32> (<32 x i32>, <32 x i32>): qf32 type used as sf at operand 1
; CHECK: warning: test.c:13:10: in function foo <64 x i32> (<32 x i32>, <32 x i32>): qf32 type used as sf at operand 2
entry:
  call void @llvm.dbg.value(metadata <32 x i32> %vina, metadata !22, metadata !DIExpression()), !dbg !35
  call void @llvm.dbg.value(metadata <32 x i32> %vinb, metadata !23, metadata !DIExpression()), !dbg !35
  %0 = tail call <32 x i32> @llvm.hexagon.V6.lvsplath.128B(i32 15360), !dbg !36
  call void @llvm.dbg.value(metadata <32 x i32> %0, metadata !24, metadata !DIExpression()), !dbg !35
  %1 = tail call <32 x i32> @llvm.hexagon.V6.lvsplath.128B(i32 48128), !dbg !37
  call void @llvm.dbg.value(metadata <32 x i32> %1, metadata !26, metadata !DIExpression()), !dbg !35
  %2 = tail call <32 x i32> @llvm.hexagon.V6.lvsplatw.128B(i32 44032), !dbg !38
  call void @llvm.dbg.value(metadata <32 x i32> %2, metadata !27, metadata !DIExpression()), !dbg !35
  %3 = tail call <32 x i32> @llvm.hexagon.V6.lvsplatw.128B(i32 56320), !dbg !39
  call void @llvm.dbg.value(metadata <32 x i32> %3, metadata !28, metadata !DIExpression()), !dbg !35
  %4 = tail call <32 x i32> @llvm.hexagon.V6.vadd.qf16.mix.128B(<32 x i32> %0, <32 x i32> %1), !dbg !40
  call void @llvm.dbg.value(metadata <32 x i32> %4, metadata !29, metadata !DIExpression()), !dbg !35
  %5 = tail call <32 x i32> @llvm.hexagon.V6.vadd.qf32.mix.128B(<32 x i32> %2, <32 x i32> %3), !dbg !41
  call void @llvm.dbg.value(metadata <32 x i32> %5, metadata !30, metadata !DIExpression()), !dbg !35
  %6 = tail call <64 x i32> @llvm.hexagon.V6.vmpy.qf32.qf16.128B(<32 x i32> %vina, <32 x i32> %4), !dbg !42
  call void @llvm.dbg.value(metadata <64 x i32> %6, metadata !31, metadata !DIExpression()), !dbg !35
  %7 = tail call <64 x i32> @llvm.hexagon.V6.vmpy.qf32.hf.128B(<32 x i32> %vinb, <32 x i32> %4), !dbg !43
  call void @llvm.dbg.value(metadata <64 x i32> %7, metadata !32, metadata !DIExpression()), !dbg !35
  %8 = tail call <32 x i32> @llvm.hexagon.V6.hi.128B(<64 x i32> %6), !dbg !44
  %9 = tail call <32 x i32> @llvm.hexagon.V6.vsub.qf32.mix.128B(<32 x i32> %8, <32 x i32> %5), !dbg !45
  call void @llvm.dbg.value(metadata <32 x i32> %9, metadata !33, metadata !DIExpression()), !dbg !35
  %10 = tail call <32 x i32> @llvm.hexagon.V6.hi.128B(<64 x i32> %7), !dbg !46
  %11 = tail call <32 x i32> @llvm.hexagon.V6.vsub.qf32.128B(<32 x i32> %10, <32 x i32> %5), !dbg !47
  call void @llvm.dbg.value(metadata <32 x i32> %11, metadata !34, metadata !DIExpression()), !dbg !35
  %12 = tail call <64 x i32> @llvm.hexagon.V6.vcombine.128B(<32 x i32> %11, <32 x i32> %9), !dbg !48
  ret <64 x i32> %12, !dbg !49
}

declare <32 x i32> @llvm.hexagon.V6.lvsplath.128B(i32) #1
declare <32 x i32> @llvm.hexagon.V6.lvsplatw.128B(i32) #1
declare <32 x i32> @llvm.hexagon.V6.vadd.qf16.mix.128B(<32 x i32>, <32 x i32>) #1
declare <32 x i32> @llvm.hexagon.V6.vadd.qf32.mix.128B(<32 x i32>, <32 x i32>) #1
declare <64 x i32> @llvm.hexagon.V6.vmpy.qf32.qf16.128B(<32 x i32>, <32 x i32>) #1
declare <64 x i32> @llvm.hexagon.V6.vmpy.qf32.hf.128B(<32 x i32>, <32 x i32>) #1
declare <32 x i32> @llvm.hexagon.V6.vsub.qf32.mix.128B(<32 x i32>, <32 x i32>) #1
declare <32 x i32> @llvm.hexagon.V6.hi.128B(<64 x i32>) #1
declare <32 x i32> @llvm.hexagon.V6.vsub.qf32.128B(<32 x i32>, <32 x i32>) #1
declare <64 x i32> @llvm.hexagon.V6.vcombine.128B(<32 x i32>, <32 x i32>) #1
declare void @llvm.dbg.value(metadata, metadata, metadata) #2

attributes #0 = { mustprogress nofree nosync nounwind willreturn memory(none) "approx-func-fp-math"="true" "frame-pointer"="all" "no-infs-fp-math"="true" "no-nans-fp-math"="true" "no-signed-zeros-fp-math"="true" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="hexagonv79" "target-features"="+hvx-length128b,+hvx-qfloat,+hvxv79,+v79,-long-calls" "unsafe-fp-math"="true" }
attributes #1 = { mustprogress nocallback nofree nosync nounwind willreturn memory(none) }
attributes #2 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!2, !3, !4, !5, !6}
!llvm.ident = !{!7}

!0 = distinct !DICompileUnit(language: DW_LANG_C11, file: !1, producer: "QuIC LLVM Hexagon Clang version 8.8-alpha2 Engineering Release: hexagon-clang-88-5172", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, splitDebugInlining: false, debugInfoForProfiling: true, nameTableKind: None)
!1 = !DIFile(filename: "test.c", directory: "/local/mnt/workspace/santdas/src/8_8/build")
!2 = !{i32 7, !"Dwarf Version", i32 4}
!3 = !{i32 2, !"Debug Info Version", i32 3}
!4 = !{i32 1, !"wchar_size", i32 4}
!5 = !{i32 7, !"frame-pointer", i32 2}
!6 = !{i32 7, !"debug-info-assignment-tracking", i1 true}
!7 = !{!"QuIC LLVM Hexagon Clang version 8.8-alpha2 Engineering Release: hexagon-clang-88-5172"}
!8 = distinct !DISubprogram(name: "foo", scope: !1, file: !1, line: 2, type: !9, scopeLine: 2, flags: DIFlagPrototyped | DIFlagAllCallsDescribed, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0, retainedNodes: !21)
!9 = !DISubroutineType(types: !10)
!10 = !{!11, !17, !17}
!11 = !DIDerivedType(tag: DW_TAG_typedef, name: "HEXAGON_Vect2048", file: !12, line: 1223, baseType: !13, align: 2048)
!12 = !DIFile(filename: "./install/Tools/bin/../target/hexagon/include/hexagon_types.h", directory: "/local/mnt/workspace/santdas/src/8_8/build")
!13 = !DICompositeType(tag: DW_TAG_array_type, baseType: !14, size: 2048, flags: DIFlagVector, elements: !15)
!14 = !DIBasicType(name: "long", size: 32, encoding: DW_ATE_signed)
!15 = !{!16}
!16 = !DISubrange(count: 64)
!17 = !DIDerivedType(tag: DW_TAG_typedef, name: "HEXAGON_Vect1024", file: !12, line: 1220, baseType: !18, align: 1024)
!18 = !DICompositeType(tag: DW_TAG_array_type, baseType: !14, size: 1024, flags: DIFlagVector, elements: !19)
!19 = !{!20}
!20 = !DISubrange(count: 32)
!21 = !{!22, !23, !24, !26, !27, !28, !29, !30, !31, !32, !33, !34}
!22 = !DILocalVariable(name: "vina", arg: 1, scope: !8, file: !1, line: 2, type: !17)
!23 = !DILocalVariable(name: "vinb", arg: 2, scope: !8, file: !1, line: 2, type: !17)
!24 = !DILocalVariable(name: "ishf1", scope: !8, file: !1, line: 3, type: !25)
!25 = !DIDerivedType(tag: DW_TAG_const_type, baseType: !17)
!26 = !DILocalVariable(name: "ishf2", scope: !8, file: !1, line: 4, type: !25)
!27 = !DILocalVariable(name: "issf1", scope: !8, file: !1, line: 5, type: !25)
!28 = !DILocalVariable(name: "issf2", scope: !8, file: !1, line: 6, type: !25)
!29 = !DILocalVariable(name: "isqf16", scope: !8, file: !1, line: 7, type: !25)
!30 = !DILocalVariable(name: "isqf32", scope: !8, file: !1, line: 8, type: !25)
!31 = !DILocalVariable(name: "isqf32_1", scope: !8, file: !1, line: 9, type: !11)
!32 = !DILocalVariable(name: "isqf32_2", scope: !8, file: !1, line: 10, type: !11)
!33 = !DILocalVariable(name: "add1", scope: !8, file: !1, line: 11, type: !17)
!34 = !DILocalVariable(name: "add2", scope: !8, file: !1, line: 12, type: !17)
!35 = !DILocation(line: 0, scope: !8)
!36 = !DILocation(line: 3, column: 34, scope: !8)
!37 = !DILocation(line: 4, column: 34, scope: !8)
!38 = !DILocation(line: 5, column: 34, scope: !8)
!39 = !DILocation(line: 6, column: 34, scope: !8)
!40 = !DILocation(line: 7, column: 35, scope: !8)
!41 = !DILocation(line: 8, column: 35, scope: !8)
!42 = !DILocation(line: 9, column: 31, scope: !8)
!43 = !DILocation(line: 10, column: 31, scope: !8)
!44 = !DILocation(line: 11, column: 67, scope: !8)
!45 = !DILocation(line: 11, column: 27, scope: !8)
!46 = !DILocation(line: 12, column: 63, scope: !8)
!47 = !DILocation(line: 12, column: 27, scope: !8)
!48 = !DILocation(line: 13, column: 10, scope: !8)
!49 = !DILocation(line: 13, column: 3, scope: !8)
