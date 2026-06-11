; RUN: llc -mtriple=hexagon -mattr=+reserved-r19 < %s | FileCheck %s
;; Test that the backend fatally errors without reserved-r19
; RUN: not --crash llc -mtriple=hexagon < %s 2>&1 | FileCheck %s --check-prefix=ERR
; RUN: llc -mtriple=hexagon -mattr=+reserved-r19 < %s | FileCheck %s --check-prefix=CFI
; RUN: llc -mtriple=hexagon-unknown-linux-musl -mattr=+reserved-r19 < %s | FileCheck %s --check-prefix=MUSL

;; Leaf function - no LR spill, SCS should not emit any r19 instructions.
; CHECK-LABEL: leaf:
; CHECK-NOT: r19
; CHECK: jumpr r31

;; Non-leaf function - SCS emits prologue (addi + store) and epilogue (load + addi).
;; The SCS store is fused into the same packet as the first call; because
;; Hexagon packets use old-value reads the original R31 is saved regardless.
;; The epilogue load and addi are also in the same packet; the load uses the
;; old (pre-decrement) r19 value per Hexagon packet semantics, and the -4
;; offset correctly addresses the saved slot.
; CHECK-LABEL: nonleaf:
; CHECK:      r19 = add(r19,#4)
; CHECK:      call bar
; CHECK:      memw(r19+#-4) = r31
; CHECK-DAG:  r19 = add(r19,#-4)
; CHECK-DAG:  r31 = memw(r19+#-4)
; CHECK:      jumpr r31

;; Multi-call function - only one SCS prologue/epilogue pair, not one per call.
; CHECK-LABEL: twocalls:
; CHECK:      r19 = add(r19,#4)
; CHECK:      call bar
; CHECK:      memw(r19+#-4) = r31
; CHECK:      call bar
; CHECK-DAG:  r19 = add(r19,#-4)
; CHECK-DAG:  r31 = memw(r19+#-4)
; CHECK:      jumpr r31

;; Conditional call (shrink-wrapping): the early-return path is a leaf and
;; has no SCS prologue/epilogue.  The call path gets the SCS pair.
; CHECK-LABEL: condcall:
; CHECK:       if (!p0.new) jumpr:nt r31
; CHECK:       r19 = add(r19,#4)
; CHECK:       call bar
; CHECK:       memw(r19+#-4) = r31
; CHECK-DAG:   r19 = add(r19,#-4)
; CHECK-DAG:   r31 = memw(r19+#-4)
; CHECK:       jumpr r31

;; Tail call - SCS prologue and epilogue are both emitted; the epilogue
;; instructions and the tail jump are fused into the same packet.
; CHECK-LABEL: tailcall:
; CHECK:      r19 = add(r19,#4)
; CHECK:      memw(r19+#-4) = r31
; CHECK-DAG:  r19 = add(r19,#-4)
; CHECK-DAG:  r31 = memw(r19+#-4)
; CHECK-DAG:  jump bar

;; Noreturn call - SCS prologue is emitted but no SCS epilogue since the
;; function never returns.
; CHECK-LABEL: noret:
; CHECK:      r19 = add(r19,#4)
; CHECK:      memw(r19+#-4) = r31
; CHECK-NOT:  r31 = memw
; CHECK-NOT:  r19 = add(r19,#-4)
; CHECK-LABEL: nonleaf_cfi:

;; Without r19 reserved, SCS should report an error.
; ERR: Must reserve r19 to use shadow call stack on Hexagon

;; Non-leaf with uwtable - exercises CFI escape (DW_CFA_val_expression for r19)
;; and cfi_restore on epilogue.
; CFI-LABEL: nonleaf_cfi:
; CFI:        r19 = add(r19,#4)
; CFI:        memw(r19+#-4) = r31
; CFI:        .cfi_escape 0x16, 0x13, 0x02, 0x83, 0x7c
; CFI-DAG:    r31 = memw(r19+#-4)
; CFI-DAG:    r19 = add(r19,#-4)
; CFI:        .cfi_restore r19
; CFI:        jumpr r31

;; Musl vararg - exercises the vararg epilogue path with SCS.
; MUSL-LABEL: vararg_musl:
; MUSL:       r19 = add(r19,#4)
; MUSL:       memw(r19+#-4) = r31
; MUSL-DAG:   r19 = add(r19,#-4)
; MUSL-DAG:   r31 = memw(r19+#-4)
; MUSL:       jumpr r31

;; Two IR-level returns reachable from distinct call paths.  Branch-folding
;; merges them into a single common-return block before PEI, so only one SCS
;; epilogue is emitted - exactly matching the one prologue bump.
; CHECK-LABEL: multi_ret:
; CHECK:      r19 = add(r19,#4)
; CHECK:      memw(r19+#-4) = r31
; CHECK:      call other
; CHECK:      call bar
; CHECK-DAG:  r19 = add(r19,#-4)
; CHECK-DAG:  r31 = memw(r19+#-4)
; CHECK:      jumpr r31

;; EH_RETURN_JMPR path - the normal return gets an SCS epilogue, the EH return
;; path does not (EH overwrites R31 with the handler address and the unwinder
;; uses the CFI val_expression to recover r19).
; CHECK-LABEL: eh_return_scs:
; CHECK:      r19 = add(r19,#4)
; CHECK:      memw(r19+#-4) = r31
;; Normal-return epilogue:
; CHECK-DAG:  r31 = memw(r19+#-4)
; CHECK-DAG:  r19 = add(r19,#-4)
; CHECK:      jumpr r31
;; EH return path: deallocframe + add(sp, r28) + jumpr r31, but no SCS
;; load/decrement of r19 in between.
; CHECK:      deallocframe
; CHECK-NOT:  r31 = memw(r19+#-4)
; CHECK-NOT:  r19 = add(r19,#-4)
; CHECK:      jumpr r31

;; Tail call with many CSRs clobbered - would normally pick a
;; RESTORE_DEALLOC_BEFORE_TAILCALL stub, but -ffixed-r19 forces the regular
;; deallocframe path so the SCS epilogue is emittable and the backstop
;; report_fatal_error in insertEpilogueInBlock stays unreachable.
; CHECK-LABEL: tailcall_many_csrs:
; CHECK-NOT:  restore_
; CHECK:      r19 = add(r19,#4)
; CHECK:      memw(r19+#-4) = r31
; CHECK-DAG:  r19 = add(r19,#-4)
; CHECK-DAG:  r31 = memw(r19+#-4)
; CHECK-DAG:  jump bar

;; Tail call + uwtable - combines the CFI escape/restore with the tail-call
;; epilogue shape.
; CFI-LABEL: tailcall_uwtable:
; CFI:        r19 = add(r19,#4)
; CFI:        memw(r19+#-4) = r31
; CFI:        .cfi_escape 0x16, 0x13, 0x02, 0x83, 0x7c
; CFI-DAG:    r31 = memw(r19+#-4)
; CFI-DAG:    r19 = add(r19,#-4)
; CFI:        .cfi_restore r19
; CFI:        jump bar

declare void @bar()
declare i32 @other(i32)
declare i32 @setup()
declare void @llvm.eh.return.i32(i32, ptr) nounwind

define void @leaf() shadowcallstack nounwind {
  ret void
}

define void @nonleaf() shadowcallstack nounwind {
  call void @bar()
  ret void
}

define void @twocalls() shadowcallstack nounwind {
  call void @bar()
  call void @bar()
  ret void
}

define void @condcall(i1 %cond) shadowcallstack nounwind {
  br i1 %cond, label %call, label %ret
call:
  call void @bar()
  br label %ret
ret:
  ret void
}

define void @tailcall() shadowcallstack nounwind {
  call void @bar()
  tail call void @bar()
  ret void
}

define void @noret() shadowcallstack nounwind {
  call void @bar() noreturn
  unreachable
}

define void @nonleaf_cfi() shadowcallstack uwtable {
  call void @bar()
  ret void
}

define void @vararg_musl(i32 %a, ...) shadowcallstack nounwind {
  call void @bar()
  ret void
}

define i32 @multi_ret(i1 %c, i32 %x) shadowcallstack nounwind {
  br i1 %c, label %a, label %b
a:
  %ra = call i32 @other(i32 %x)
  ret i32 %ra
b:
  call void @bar()
  %rb = add i32 %x, 7
  ret i32 %rb
}

define i32 @eh_return_scs(i32 %a, i32 %b) shadowcallstack nounwind {
entry:
  %cmp = icmp sgt i32 %a, %b
  br i1 %cmp, label %if.then, label %if.else
if.then:
  %add = add nsw i32 %a, %b
  ret i32 %add
if.else:
  %call = call i32 @setup()
  call void @llvm.eh.return.i32(i32 %call, ptr null)
  unreachable
}

define void @tailcall_many_csrs() shadowcallstack nounwind {
  call void @bar()
  call void asm sideeffect "", "~{r16},~{r17},~{r18},~{r20},~{r21},~{r22},~{r23},~{r24},~{r25},~{r26},~{r27}"()
  tail call void @bar()
  ret void
}

define void @tailcall_uwtable() shadowcallstack uwtable {
  call void @bar()
  tail call void @bar()
  ret void
}
