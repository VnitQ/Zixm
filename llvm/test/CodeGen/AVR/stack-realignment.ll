; RUN: llc -mtriple=avr -mcpu=atmega328 -O1 -verify-machineinstrs < %s | FileCheck %s

declare void @use(ptr %x);

; This function exists for comparison, so that it's easy to see what changes
; when stack realignment gets activated - no realignment happens here yet.
define i8 @no_align() {
; CHECK-LABEL: no_align:
; CHECK-NEXT: ; %bb.0:
;
;; prologue
; CHECK-NEXT: push r28
; CHECK-NEXT: push r29
; CHECK-NEXT: in r28, 61
; CHECK-NEXT: in r29, 62
; CHECK-NEXT: sbiw r28, 1
; CHECK-NEXT: in r0, 63
; CHECK-NEXT: cli
; CHECK-NEXT: out 62, r29
; CHECK-NEXT: out 63, r0
; CHECK-NEXT: out 61, r28
;
;; call void @use(ptr %1)
; CHECK-NEXT: movw r24, r28
; CHECK-NEXT: adiw r24, 1
; CHECK-NEXT: call use
;
;; %2 = load i8, ptr %1, align 1
; CHECK-NEXT: ldd r24, Y+1
;
;; epilogue
; CHECK-NEXT: adiw r28, 1
; CHECK-NEXT: in r0, 63
; CHECK-NEXT: cli
; CHECK-NEXT: out 62, r29
; CHECK-NEXT: out 63, r0
; CHECK-NEXT: out 61, r28
; CHECK-NEXT: pop r29
; CHECK-NEXT: pop r28
; CHECK-NEXT: ret

  %1 = alloca i8, align 1
  call void @use(ptr %1)
  %2 = load i8, ptr %1, align 1

  ret i8 %2
}

define i8 @small_align() {
; CHECK-LABEL: small_align:
; CHECK-NEXT: %bb.0:
;
;; prologue
; CHECK-NEXT: push r16
; CHECK-NEXT: push r17
; CHECK-NEXT: push r28
; CHECK-NEXT: push r29
; CHECK-NEXT: in r28, 61
; CHECK-NEXT: in r29, 62
; CHECK-NEXT: sbiw r28, 8
; CHECK-NEXT: in r0, 63
; CHECK-NEXT: cli
; CHECK-NEXT: out 62, r29
; CHECK-NEXT: out 63, r0
; CHECK-NEXT: out 61, r28
;
;; prologue (SP allocation)
; CHECK-NEXT: movw r16, r28
; CHECK-NEXT: subi r16, 254
; CHECK-NEXT: sbci r17, 255
; CHECK-NEXT: andi r16, 254
;
;; call void @use (ptr %1)
; CHECK-NEXT: movw r24, r16
; CHECK-NEXT: call use
;; ^ uses r16 (SP) instead of r28 (FP)
;
;; %2 = load i8, ptr %1, align 2
; CHECK-NEXT: movw r30, r16
; CHECK-NEXT: ldd r24, Z+0
;; ^ uses r31r30 as a temporary, since AVR doesn't have `ldd r24, r17r16+0`
;
;; epilogue
; CHECK-NEXT: adiw r28, 8
; CHECK-NEXT: in r0, 63
; CHECK-NEXT: cli
; CHECK-NEXT: out 62, r29
; CHECK-NEXT: out 63, r0
; CHECK-NEXT: out 61, r28
; CHECK-NEXT: pop r29
; CHECK-NEXT: pop r28
; CHECK-NEXT: pop r17
; CHECK-NEXT: pop r16
; CHECK-NEXT: ret

  %1 = alloca i8, align 2
  call void @use(ptr %1)
  %2 = load i8, ptr %1, align 2

  ret i8 %2
}

define i8 @large_align() {
; CHECK-LABEL: large_align:
; CHECK-NEXT: %bb.0:
;
;; prologue
; CHECK-NEXT: push r16
; CHECK-NEXT: push r17
; CHECK-NEXT: push r28
; CHECK-NEXT: push r29
; CHECK-NEXT: in r28, 61
; CHECK-NEXT: in r29, 62
; CHECK-NEXT: sbiw r28, 16
; CHECK-NEXT: in r0, 63
; CHECK-NEXT: cli
; CHECK-NEXT: out 62, r29
; CHECK-NEXT: out 63, r0
; CHECK-NEXT: out 61, r28
;
;; prologue (SP allocation)
; CHECK-NEXT: movw r16, r28
; CHECK-NEXT: subi r16, 240
; CHECK-NEXT: sbci r17, 255
; CHECK-NEXT: andi r16, 240
;
;; call void @use (ptr %1)
; CHECK-NEXT: movw r24, r16
; CHECK-NEXT: call use
;
;; %2 = load i8, ptr %1, align 16
; CHECK-NEXT: movw r30, r16
; CHECK-NEXT: ldd r24, Z+0
;
;; epilogue
; CHECK-NEXT: adiw r28, 16
; CHECK-NEXT: in r0, 63
; CHECK-NEXT: cli
; CHECK-NEXT: out 62, r29
; CHECK-NEXT: out 63, r0
; CHECK-NEXT: out 61, r28
; CHECK-NEXT: pop r29
; CHECK-NEXT: pop r28
; CHECK-NEXT: pop r17
; CHECK-NEXT: pop r16
; CHECK-NEXT: ret

  %1 = alloca i8, align 16
  call void @use(ptr %1)
  %2 = load i8, ptr %1, align 16

  ret i8 %2
}

define i8 @align_many() {
; CHECK-LABEL: align_many:
; CHECK-NEXT: %bb.0:
;
;; prologue
; CHECK-NEXT: push r16
; CHECK-NEXT: push r17
; CHECK-NEXT: push r28
; CHECK-NEXT: push r29
; CHECK-NEXT: in r28, 61
; CHECK-NEXT: in r29, 62
; CHECK-NEXT: sbiw r28, 24
; CHECK-NEXT: in r0, 63
; CHECK-NEXT: cli
; CHECK-NEXT: out 62, r29
; CHECK-NEXT: out 63, r0
; CHECK-NEXT: out 61, r28
;
;; prologue (SP allocation)
; CHECK-NEXT: movw r16, r28
; CHECK-NEXT: subi r16, 248
; CHECK-NEXT: sbci r17, 255
; CHECK-NEXT: andi r16, 248
;
;; call void @use (ptr %1)
; CHECK-NEXT: movw r24, r16
; CHECK-NEXT: adiw r24, 16
; CHECK-NEXT: call use
;
;; call void @use (ptr %2)
; CHECK-NEXT: movw r24, r16
; CHECK-NEXT: adiw r24, 8
; CHECK-NEXT: call use
;
;; call void @use (ptr %3)
; CHECK-NEXT: movw r24, r16
; CHECK-NEXT: call use
;
;; %5 = load i8, ptr %2, align 8
; CHECK-NEXT: movw r30, r16
; CHECK-NEXT: ldd r24, Z+8
;
;; %4 = load i8, ptr %1, align 8
; CHECK-NEXT: movw r30, r16
; CHECK-NEXT: ldd r25, Z+16
;
;; %7 = or i8 %4, %5
; CHECK-NEXT: or r25, r24
;
;; %6 = load i8, ptr %3, align 8
; CHECK-NEXT: movw r30, r16
; CHECK-NEXT: ldd r24, Z+0
;
;; %8 = or i8 %6, %7
; CHECK-NEXT: or r24, r25
;
;; epilogue
; CHECK-NEXT: adiw r28, 24
; CHECK-NEXT: in r0, 63
; CHECK-NEXT: cli
; CHECK-NEXT: out 62, r29
; CHECK-NEXT: out 63, r0
; CHECK-NEXT: out 61, r28
; CHECK-NEXT: pop r29
; CHECK-NEXT: pop r28
; CHECK-NEXT: pop r17
; CHECK-NEXT: pop r16
; CHECK-NEXT: ret

  %1 = alloca i8, align 8
  %2 = alloca i8, align 8
  %3 = alloca i8, align 8

  call void @use(ptr %1)
  call void @use(ptr %2)
  call void @use(ptr %3)

  %4 = load i8, ptr %1, align 8
  %5 = load i8, ptr %2, align 8
  %6 = load i8, ptr %3, align 8

  ; Prevent optimizer from removing the loads
  %7 = or i8 %4, %5
  %8 = or i8 %6, %7

  ret i8 %8
}

define i8 @align_many_mixed() {
; CHECK-LABEL: align_many_mixed:
; CHECK-NEXT: %bb.0:
;
;; prologue
; CHECK-NEXT: push r16
; CHECK-NEXT: push r17
; CHECK-NEXT: push r28
; CHECK-NEXT: push r29
; CHECK-NEXT: in r28, 61
; CHECK-NEXT: in r29, 62
; CHECK-NEXT: sbiw r28, 16
; CHECK-NEXT: in r0, 63
; CHECK-NEXT: cli
; CHECK-NEXT: out 62, r29
; CHECK-NEXT: out 63, r0
; CHECK-NEXT: out 61, r28
;
;; prologue (SP allocation)
; CHECK-NEXT: movw r16, r28
; CHECK-NEXT: subi r16, 248
; CHECK-NEXT: sbci r17, 255
; CHECK-NEXT: andi r16, 248
;
;; call void @use (ptr %1)
; CHECK-NEXT: movw r24, r16
; CHECK-NEXT: adiw r24, 8
; CHECK-NEXT: call use
;
;; call void @use (ptr %2)
; CHECK-NEXT: movw r24, r16
; CHECK-NEXT: adiw r24, 7
; CHECK-NEXT: call use
;
;; call void @use (ptr %3)
; CHECK-NEXT: movw r24, r16
; CHECK-NEXT: call use
;
;; %5 = load i8, ptr %2, align 1
; CHECK-NEXT: movw r30, r16
; CHECK-NEXT: ldd r24, Z+7
;
;; %4 = load i8, ptr %1, align 8
; CHECK-NEXT: movw r30, r16
; CHECK-NEXT: ldd r25, Z+8
;
;; %7 = or i8 %4, %5
; CHECK-NEXT: or r25, r24
;
;; %6 = load i8, ptr %3, align 8
; CHECK-NEXT: movw r30, r16
; CHECK-NEXT: ldd r24, Z+0
;
;; %8 = or i8 %6, %7
; CHECK-NEXT: or r24, r25
;
;; epilogue
; CHECK-NEXT: adiw r28, 16
; CHECK-NEXT: in r0, 63
; CHECK-NEXT: cli
; CHECK-NEXT: out 62, r29
; CHECK-NEXT: out 63, r0
; CHECK-NEXT: out 61, r28
; CHECK-NEXT: pop r29
; CHECK-NEXT: pop r28
; CHECK-NEXT: pop r17
; CHECK-NEXT: pop r16
; CHECK-NEXT: ret

  %1 = alloca i8, align 8
  %2 = alloca i8, align 1 ; the square peg
  %3 = alloca i8, align 8

  call void @use(ptr %1)
  call void @use(ptr %2)
  call void @use(ptr %3)

  %4 = load i8, ptr %1, align 8
  %5 = load i8, ptr %2, align 1
  %6 = load i8, ptr %3, align 8

  ; Prevent optimizer from removing the loads
  %7 = or i8 %4, %5
  %8 = or i8 %6, %7

  ret i8 %8
}

; Make sure we can carry out both SP-relative and FP-relative loads within a
; single function.
;
; Code below corresponds to:
;
; ```
; uint8_t with_fixed_object(SomeLargeType, uint8_t x) {
;   _Alignas(8) uint8_t y;
;
;   use(&x);
;   use(&y);
;
;   return x | y;
; }
; ```
;
; ... and what we want to make sure is that `use(&x)` utilizes frame pointer and
; `use(&y)` utilizes stack pointer.
;
; We need for the first argument here to be large, because otherwise `x` (`%2`
; below) would be passed via registers and we need it to be placed on the stack
; for `use(&x)` to go through what LLVM calls a _fixed object_.
;
; i.e. we need for `%2` to be passed on stack, not via registers
define i8 @with_fixed_object(i256 %1, i8 %2) {
; CHECK-LABEL: with_fixed_object:
; CHECK-NEXT: %bb.0:
;
;; prologue
; CHECK-NEXT: push r16
; CHECK-NEXT: push r17
; CHECK-NEXT: push r28
; CHECK-NEXT: push r29
; CHECK-NEXT: in r28, 61
; CHECK-NEXT: in r29, 62
; CHECK-NEXT: sbiw r28, 8
; CHECK-NEXT: in r0, 63
; CHECK-NEXT: cli
; CHECK-NEXT: out 62, r29
; CHECK-NEXT: out 63, r0
; CHECK-NEXT: out 61, r28
;
;; prologue (SP allocation)
; CHECK-NEXT: movw r16, r28
; CHECK-NEXT: subi r16, 248
; CHECK-NEXT: sbci r17, 255
; CHECK-NEXT: andi r16, 248
;
;; store i8 %2, ptr %4, align 1
;; call void @use(ptr %4)
; CHECK-NEXT: movw r24, r28
; CHECK-NEXT: adiw r24, 47
; CHECK-NEXT: call use
;; ^ note that the store gets eliminated - in a way we use it merely as a proxy
;;   for what we really want, `addrOf(%2)`
;
;; call void @use(ptr %5)
; CHECK-NEXT: movw r24, r16
; CHECK-NEXT: call use
;
;; %7 = load i8, ptr %5, align 8
; CHECK-NEXT: movw r30, r16
; CHECK-NEXT: ldd r25, Z+0
;
; %6 = load i8, ptr %4, align 1
; CHECK-NEXT: ldd r24, Y+47
;
;; %8 = or i8 %6, %7
; CHECK-NEXT: or r24, r25
;
;; epilogue
; CHECK-NEXT: adiw r28, 8
; CHECK-NEXT: in r0, 63
; CHECK-NEXT: cli
; CHECK-NEXT: out 62, r29
; CHECK-NEXT: out 63, r0
; CHECK-NEXT: out 61, r28
; CHECK-NEXT: pop r29
; CHECK-NEXT: pop r28
; CHECK-NEXT: pop r17
; CHECK-NEXT: pop r16
; CHECK-NEXT: ret

  %4 = alloca i8, align 1
  %5 = alloca i8, align 8

  store i8 %2, ptr %4, align 1

  call void @use(ptr %4)
  call void @use(ptr %5)

  %6 = load i8, ptr %4, align 1
  %7 = load i8, ptr %5, align 8
  %8 = or i8 %6, %7

  ret i8 %8
}

; Make sure we can handle cases where LLVM tells us to perform a read into
; r31r30 itself:
;
; ```
; early-clobber $r31r30 = LDDWRdPtrQ %stack.0
; ```
;
; This is awkward, because for aligned stacks we already use r31r30 as a
; temporary register to which we copy %stack.0 - i.e. we do something like:
;
; ```
; $r31r30 = COPY %r17r16
; early-clobber $reg = LDDWRdPtrQ killed %r31r30
; ```
;
; Naturally, this doesn't work when $reg == $r31r30 and so that needs a less
; optimal expansion.
define i64 @with_occupied_r31r30(i64 %0) {
; CHECK-LABEL: with_occupied_r31r30:
; CHECK-NEXT: %bb.0:
;
;; prologue
; CHECK-NEXT: push r16
; CHECK-NEXT: push r17
; CHECK-NEXT: push r28
; CHECK-NEXT: push r29
; CHECK-NEXT: in r28, 61
; CHECK-NEXT: in r29, 62
; CHECK-NEXT: sbiw r28, 16
; CHECK-NEXT: in r0, 63
; CHECK-NEXT: cli
; CHECK-NEXT: out 62, r29
; CHECK-NEXT: out 63, r0
; CHECK-NEXT: out 61, r28
;
;; prologue (SP allocation)
; CHECK-NEXT: movw r16, r28
; CHECK-NEXT: subi r16, 252
; CHECK-NEXT: sbci r17, 255
; CHECK-NEXT: andi r16, 252
;
;; %3 = load i64, ptr %2, align 4
; CHECK-NEXT: push r28
; CHECK-NEXT: push r29
; CHECK-NEXT: movw r28, r16
; CHECK-NEXT: ldd r30, Y+0
; CHECK-NEXT: ldd r31, Y+1
; CHECK-NEXT: pop r29
; CHECK-NEXT: pop r28
; CHECK-NEXT: or r18, r30
; CHECK-NEXT: or r19, r31

  %2 = alloca [1 x i64], align 4
  %3 = load i64, ptr %2, align 4
  %4 = or i64 %3, %0

  ret i64 %4
}
