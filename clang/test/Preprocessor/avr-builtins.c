// RUN: %clang_cc1 -E -dM -triple avr-unknown-unknown -target-cpu atmega328p %s | FileCheck %s

// CHECK: #define __BUILTIN_AVR_CLI 1
// CHECK: #define __BUILTIN_AVR_DELAY_CYCLES 1
// CHECK: #define __BUILTIN_AVR_FLASH_SEGMENT 1
// CHECK: #define __BUILTIN_AVR_FMUL 1
// CHECK: #define __BUILTIN_AVR_FMULS 1
// CHECK: #define __BUILTIN_AVR_FMULSU 1
// CHECK: #define __BUILTIN_AVR_INSERT_BITS 1
// CHECK: #define __BUILTIN_AVR_NOP 1
// CHECK: #define __BUILTIN_AVR_NOPS 1
// CHECK: #define __BUILTIN_AVR_SEI 1
// CHECK: #define __BUILTIN_AVR_SLEEP 1
// CHECK: #define __BUILTIN_AVR_SWAP 1
// CHECK: #define __BUILTIN_AVR_WDR 1
