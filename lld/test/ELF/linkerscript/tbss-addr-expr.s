# REQUIRES: x86
## Test that an explicit address expression on a .tbss section is respected.

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

## Test that an explicit address on a tbss section is honored.
# RUN: echo 'SECTIONS { \
# RUN:   . = SIZEOF_HEADERS; \
# RUN:   .text : { *(.text) } \
# RUN:   .tbss 0x1000 : { *(.tbss) } \
# RUN:   .data : { *(.data) } \
# RUN: }' > %t.lds
# RUN: ld.lld -T %t.lds %t.o -o %t
# RUN: llvm-readelf -S %t | FileCheck %s

# CHECK:      .tbss NOBITS 0000000000001000 {{[0-9a-f]+}} 000004

## Test that an expression (not just a constant) works for tbss address.
# RUN: echo 'SECTIONS { \
# RUN:   . = SIZEOF_HEADERS; \
# RUN:   .text : { *(.text) } \
# RUN:   .tbss (0x800 + 0x800) : { *(.tbss) } \
# RUN:   .data : { *(.data) } \
# RUN: }' > %t2.lds
# RUN: ld.lld -T %t2.lds %t.o -o %t2
# RUN: llvm-readelf -S %t2 | FileCheck %s --check-prefix=CHECK2

# CHECK2:      .tbss NOBITS 0000000000001000 {{[0-9a-f]+}} 000004

## Test that .data follows .text, not .tbss (since tbss is SHT_NOBITS).
# RUN: echo 'SECTIONS { \
# RUN:   .text 0x1000 : { *(.text) } \
# RUN:   .tbss 0x2000 : { *(.tbss) } \
# RUN:   .data : { *(.data) } \
# RUN: }' > %t3.lds
# RUN: ld.lld -T %t3.lds %t.o -o %t3
# RUN: llvm-readelf -S %t3 | FileCheck %s --check-prefix=CHECK3

## .data should follow .text at 0x1001, not .tbss at 0x2004
# CHECK3:      .text PROGBITS 0000000000001000
# CHECK3:      .tbss NOBITS   0000000000002000
# CHECK3:      .data PROGBITS 0000000000001001

.globl _start
_start:
  nop

.section .tbss,"awT",@nobits
  .long 0

.section .data,"aw"
  .long 0
