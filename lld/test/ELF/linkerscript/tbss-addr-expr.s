# REQUIRES: x86
## Test that an explicit address expression on a .tbss section is respected.

# RUN: rm -rf %t && split-file %s %t
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %t/a.s -o %t/a.o

# RUN: ld.lld -T %t/explicit.t %t/a.o -o %t/explicit
# RUN: llvm-readelf -S %t/explicit | FileCheck %s --check-prefix=EXPLICIT

# RUN: ld.lld -T %t/dataafter.t %t/a.o -o %t/dataafter
# RUN: llvm-readelf -S %t/dataafter | FileCheck %s --check-prefix=DATAAFTER

# RUN: ld.lld -T %t/consec.t %t/a.o -o %t/consec
# RUN: llvm-readelf -S %t/consec | FileCheck %s --check-prefix=CONSEC

## An explicit address on a .tbss output section is honored.
# EXPLICIT: .tbss NOBITS 0000000000001000 {{[0-9a-f]+}} 000004

## .data follows .text, not .tbss — SHT_NOBITS doesn't push the location counter.
# DATAAFTER: .text PROGBITS 0000000000001000
# DATAAFTER: .tbss NOBITS   0000000000002000
# DATAAFTER: .data PROGBITS 0000000000001001

## When the initial tbss output section has a defined address, subsequent tbss
## output sections without addrExprs stack consecutively from its end (per the
## existing comment in LinkerScript::assignOffsets: "The address range starts
## from the end address of the previous tbss section"). .data still follows
## .text, unaffected by tbss layout.
# CONSEC: .text  PROGBITS 0000000000000100
# CONSEC: .tbss1 NOBITS   0000000000001000
# CONSEC: .tbss2 NOBITS   0000000000001004
# CONSEC: .data  PROGBITS 0000000000000101

#--- a.s
.globl _start
_start:
  nop

.section .tbss,"awT",@nobits
  .long 0

.section .tbss1,"awT",@nobits
  .long 0

.section .tbss2,"awT",@nobits
  .long 0

.section .data,"aw"
  .long 0

#--- explicit.t
SECTIONS {
  . = SIZEOF_HEADERS;
  .text : { *(.text) }
  .tbss 0x1000 : { *(.tbss) }
  .data : { *(.data) }
  /DISCARD/ : { *(.tbss1) *(.tbss2) }
}

#--- dataafter.t
SECTIONS {
  .text 0x1000 : { *(.text) }
  .tbss 0x2000 : { *(.tbss) }
  .data : { *(.data) }
  /DISCARD/ : { *(.tbss1) *(.tbss2) }
}

#--- consec.t
SECTIONS {
  .text 0x100 : { *(.text) }
  .tbss1 0x1000 : { *(.tbss1) }
  .tbss2 : { *(.tbss2) }
  .data : { *(.data) }
  /DISCARD/ : { *(.tbss) }
}
