# REQUIRES: x86
## Test that an explicit address expression on a .tbss section is respected.

# RUN: rm -rf %t && split-file %s %t
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %t/a.s -o %t/a.o

# RUN: ld.lld -T %t/explicit.t %t/a.o -o %t/explicit
# RUN: llvm-readelf -S %t/explicit | FileCheck %s --check-prefix=EXPLICIT

## An explicit address on a .tbss output section is honored.
# EXPLICIT: .tbss NOBITS 0000000000200000 {{[0-9a-f]+}} 000004

#--- a.s
.globl _start
_start:
  nop

.section .tbss,"awT",@nobits
  .long 0

#--- explicit.t
MEMORY {
  text_mem (rx) : ORIGIN = 0xFFFFFFFFFFF00000, LENGTH = 0x10000
  tbss_mem (rw) : ORIGIN = 0x200000,           LENGTH = 0x1000
}

SECTIONS {
  .text : { *(.text) } >text_mem AT>text_mem
  .tbss 0x200000 (NOLOAD) : { *(.tbss) } >tbss_mem AT>tbss_mem
}
