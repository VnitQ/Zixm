// RUN: %clang_cc1 -triple x86_64-unknown-linux-gnu -fclangir -emit-cir %s -o %t.cir
// RUN: FileCheck --input-file=%t.cir %s --check-prefix=CIR
// RUN: %clang_cc1 -triple x86_64-unknown-linux-gnu -fclangir -emit-llvm %s -o %t-cir.ll
// RUN: FileCheck --input-file=%t-cir.ll %s --check-prefix=LLVM-CIR
// RUN: %clang_cc1 -triple x86_64-unknown-linux-gnu -emit-llvm %s -o %t.ll
// RUN: FileCheck --input-file=%t.ll %s --check-prefix=OGCG

// Post-increment on a bitfield: `s->nRefs++` should return the PRE-increment
// value (old value before the increment).
// Pre-increment on a bitfield: `++s->nRefs` should return the POST-increment
// value (new value after the increment).

struct S { unsigned type : 6; unsigned nRefs : 26; };

// Post-increment: returns OLD value, stores OLD+1.
int postinc(S *s) {
  return s->nRefs++;
}

// Pre-increment: returns NEW value, stores OLD+1.
int preinc(S *s) {
  return ++s->nRefs;
}

// CIR-LABEL: @_Z7postincP1S
// CIR:         %[[OLD:.*]] = cir.get_bitfield
// CIR:         %[[INC:.*]] = cir.inc %[[OLD]]
// CIR:         cir.set_bitfield {{.*}} %[[INC]]
// CIR:         cir.cast integral %[[OLD]]
// CIR-NOT:     cir.cast integral %[[INC]]

// CIR-LABEL: @_Z6preincP1S
// CIR:         %[[OLD2:.*]] = cir.get_bitfield
// CIR:         %[[INC2:.*]] = cir.inc %[[OLD2]]
// CIR:         %[[STORED:.*]] = cir.set_bitfield {{.*}} %[[INC2]]
// CIR:         cir.cast integral %[[STORED]]

// Postinc: old nRefs (lshr result, before add) goes into retval slot.
// LLVM-CIR-LABEL: @_Z7postincP1S
// LLVM-CIR:         %[[WORD:.*]] = load i32
// LLVM-CIR:         %[[OLD:.*]] = lshr i32 %[[WORD]], 6
// LLVM-CIR:         add i32 %[[OLD]], 1
// LLVM-CIR:         store i32 %[[OLD]], ptr
// LLVM-CIR:         ret i32

// Preinc: new nRefs (after add+mask) goes into retval slot.
// LLVM-CIR-LABEL: @_Z6preincP1S
// LLVM-CIR:         %[[WORD2:.*]] = load i32
// LLVM-CIR:         %[[OLD2:.*]] = lshr i32 %[[WORD2]], 6
// LLVM-CIR:         %[[NEW2:.*]] = add i32 %[[OLD2]], 1
// LLVM-CIR:         %[[MASKED:.*]] = and i32 %[[NEW2]], 67108863
// LLVM-CIR:         store i32 %[[MASKED]], ptr {{.*}}, align 4
// LLVM-CIR:         ret i32

// OGCG-LABEL: @_Z7postincP1S
// OGCG:         %[[LOAD:.*]] = load i32
// OGCG:         %[[LSHR:.*]] = lshr i32 %[[LOAD]], 6
// OGCG:         %[[INC:.*]] = add i32 %[[LSHR]], 1
// OGCG:         ret i32 %[[LSHR]]

// OGCG-LABEL: @_Z6preincP1S
// OGCG:         %[[LOAD2:.*]] = load i32
// OGCG:         %[[LSHR2:.*]] = lshr i32 %[[LOAD2]], 6
// OGCG:         %[[INC2:.*]] = add i32 %[[LSHR2]], 1
// OGCG:         %[[MASKED2:.*]] = and i32 %[[INC2]], 67108863
// OGCG:         ret i32 %[[MASKED2]]
