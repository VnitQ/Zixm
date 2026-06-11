// RUN: %clang_cc1 -triple avr-unknown-unknown -emit-llvm -o - %s | FileCheck %s

// Check that the parameter types match. This verifies pr43309.
// RUN: %clang_cc1 -triple avr-unknown-unknown -Wconversion -verify %s
// expected-no-diagnostics

unsigned char bitrev8(unsigned char data) {
    return __builtin_bitreverse8(data);
}

// CHECK: define{{.*}} i8 @bitrev8
// CHECK: i8 @llvm.bitreverse.i8(i8

unsigned int bitrev16(unsigned int data) {
    return __builtin_bitreverse16(data);
}

// CHECK: define{{.*}} i16 @bitrev16
// CHECK: i16 @llvm.bitreverse.i16(i16

unsigned long bitrev32(unsigned long data) {
    return __builtin_bitreverse32(data);
}
// CHECK: define{{.*}} i32 @bitrev32
// CHECK: i32 @llvm.bitreverse.i32(i32

unsigned long long bitrev64(unsigned long long data) {
    return __builtin_bitreverse64(data);
}

// CHECK: define{{.*}} i64 @bitrev64
// CHECK: i64 @llvm.bitreverse.i64(i64

unsigned char rotleft8(unsigned char x, unsigned char y) {
    return __builtin_rotateleft8(x, y);
}

// CHECK: define{{.*}} i8 @rotleft8
// CHECK: i8 @llvm.fshl.i8(i8

unsigned int rotleft16(unsigned int x, unsigned int y) {
    return __builtin_rotateleft16(x, y);
}

// CHECK: define{{.*}} i16 @rotleft16
// CHECK: i16 @llvm.fshl.i16(i16

unsigned long rotleft32(unsigned long x, unsigned long y) {
    return __builtin_rotateleft32(x, y);
}
// CHECK: define{{.*}} i32 @rotleft32
// CHECK: i32 @llvm.fshl.i32(i32

unsigned long long rotleft64(unsigned long long x, unsigned long long y) {
    return __builtin_rotateleft64(x, y);
}

// CHECK: define{{.*}} i64 @rotleft64
// CHECK: i64 @llvm.fshl.i64(i64

unsigned char rotright8(unsigned char x, unsigned char y) {
    return __builtin_rotateright8(x, y);
}

// CHECK: define{{.*}} i8 @rotright8
// CHECK: i8 @llvm.fshr.i8(i8

unsigned int rotright16(unsigned int x, unsigned int y) {
    return __builtin_rotateright16(x, y);
}

// CHECK: define{{.*}} i16 @rotright16
// CHECK: i16 @llvm.fshr.i16(i16

unsigned long rotright32(unsigned long x, unsigned long y) {
    return __builtin_rotateright32(x, y);
}
// CHECK: define{{.*}} i32 @rotright32
// CHECK: i32 @llvm.fshr.i32(i32

unsigned long long rotright64(unsigned long long x, unsigned long long y) {
    return __builtin_rotateright64(x, y);
}

// CHECK: define{{.*}} i64 @rotright64
// CHECK: i64 @llvm.fshr.i64(i64

unsigned int byteswap16(unsigned int x) {
    return __builtin_bswap16(x);
}

// CHECK: define{{.*}} i16 @byteswap16
// CHECK: i16 @llvm.bswap.i16(i16

unsigned long byteswap32(unsigned long x) {
    return __builtin_bswap32(x);
}
// CHECK: define{{.*}} i32 @byteswap32
// CHECK: i32 @llvm.bswap.i32(i32

unsigned long long byteswap64(unsigned long long x) {
    return __builtin_bswap64(x);
}

// CHECK: define{{.*}} i64 @byteswap64
// CHECK: i64 @llvm.bswap.i64(i64

double powi(double x, int y) {
  return __builtin_powi(x, y);
}

// CHECK: define{{.*}} float @powi
// CHECK: float @llvm.powi.f32.i16(float %0, i16 %1)

float powif(float x, int y) {
    return __builtin_powif(x, y);
}

// CHECK: define{{.*}} float @powif
// CHECK: float @llvm.powi.f32.i16(float %0, i16 %1)

long double powil(long double x, int y) {
    return __builtin_powil(x, y);
}

// CHECK: define{{.*}} float @powil
// CHECK: float @llvm.powi.f32.i16(float %0, i16 %1)

// CHECK-LABEL: define{{.*}} void @test_nop()
void test_nop(void) {
  // CHECK: call{{.*}} void @llvm.avr.nop()
  __builtin_avr_nop();
}

// CHECK-LABEL: define{{.*}} void @test_sei()
void test_sei(void) {
  // CHECK: call{{.*}} void @llvm.avr.sei()
  __builtin_avr_sei();
}

// CHECK-LABEL: define{{.*}} void @test_cli()
void test_cli(void) {
  // CHECK: call{{.*}} void @llvm.avr.cli()
  __builtin_avr_cli();
}

// CHECK-LABEL: define{{.*}} void @test_sleep()
void test_sleep(void) {
  // CHECK: call{{.*}} void @llvm.avr.sleep()
  __builtin_avr_sleep();
}

// CHECK-LABEL: define{{.*}} void @test_wdr()
void test_wdr(void) {
  // CHECK: call{{.*}} void @llvm.avr.wdr()
  __builtin_avr_wdr();
}

// CHECK-LABEL: define{{.*}} i8 @test_swap
unsigned char test_swap(unsigned char a) {
  // CHECK: call{{.*}} i8 @llvm.avr.swap(i8
  return __builtin_avr_swap(a);
}

// CHECK-LABEL: define{{.*}} i16 @test_fmul
unsigned int test_fmul(unsigned char a, unsigned char b) {
  // CHECK: call{{.*}} i16 asm sideeffect "fmul $1, $2
  return __builtin_avr_fmul(a, b);
}

// CHECK-LABEL: define{{.*}} i16 @test_fmuls
int test_fmuls(signed char a, signed char b) {
  // CHECK: call{{.*}} i16 asm sideeffect "fmuls $1, $2
  return __builtin_avr_fmuls(a, b);
}

// CHECK-LABEL: define{{.*}} i16 @test_fmulsu
int test_fmulsu(signed char a, unsigned char b) {
  // CHECK: call{{.*}} i16 asm sideeffect "fmulsu $1, $2
  return __builtin_avr_fmulsu(a, b);
}

// CHECK-LABEL: define{{.*}} void @test_nops()
void test_nops(void) {
  // CHECK: call{{.*}} void @llvm.avr.nop()
  // CHECK-NEXT: call{{.*}} void @llvm.avr.nop()
  // CHECK-NEXT: call{{.*}} void @llvm.avr.nop()
  __builtin_avr_nops(3);
}

// CHECK-LABEL: define{{.*}} void @test_delay_cycles_small()
void test_delay_cycles_small(void) {
  // 1 cycle = 1 nop
  // CHECK: call{{.*}} void asm sideeffect "nop
  __builtin_avr_delay_cycles(1);
}

// CHECK-LABEL: define{{.*}} void @test_delay_cycles_two()
void test_delay_cycles_two(void) {
  // 2 cycles = rjmp .+0
  // CHECK: call{{.*}} void asm sideeffect "rjmp .+0
  __builtin_avr_delay_cycles(2);
}

// CHECK-LABEL: define{{.*}} void @test_delay_cycles_loop()
void test_delay_cycles_loop(void) {
  // 12 cycles: 1-byte loop (4 iters = 12 cycles)
  // CHECK: call{{.*}} void asm sideeffect "ldi{{.*}}dec{{.*}}brne
  __builtin_avr_delay_cycles(12);
}

// CHECK-LABEL: define{{.*}} void @test_delay_cycles_zero()
void test_delay_cycles_zero(void) {
  // 0 cycles = empty inline asm
  // CHECK: call{{.*}} void asm sideeffect "", ""()
  __builtin_avr_delay_cycles(0);
}

// CHECK-LABEL: define{{.*}} i8 @test_insert_bits_identity
unsigned char test_insert_bits_identity(unsigned char bits, unsigned char val) {
  // Identity map: 0x76543210 — each nibble N maps bit N from 'bits'
  // CHECK: lshr
  // CHECK: and
  // CHECK: or
  return __builtin_avr_insert_bits(0x76543210UL, bits, val);
}

// CHECK-LABEL: define{{.*}} i8 @test_insert_bits_reverse
unsigned char test_insert_bits_reverse(unsigned char bits) {
  // Reverse map: 0x01234567 — reverses the bit order
  // CHECK: lshr
  // CHECK: and
  return __builtin_avr_insert_bits(0x01234567UL, bits, 0);
}

// CHECK-LABEL: define{{.*}} i8 @test_insert_bits_keep_val
unsigned char test_insert_bits_keep_val(unsigned char val) {
  // 0xFFFFFFFF — all nibbles are 0xF, keep all bits from 'val'
  // CHECK: lshr
  // CHECK: and
  return __builtin_avr_insert_bits(0xFFFFFFFFUL, 0, val);
}

// CHECK-LABEL: define{{.*}} i8 @test_flash_segment_flash
signed char test_flash_segment_flash(void) {
  const __attribute__((address_space(1))) unsigned char *p = 0;
  // __flash = addrspace(1), segment 0
  // CHECK: ret i8 0
  return __builtin_avr_flash_segment(p);
}

// CHECK-LABEL: define{{.*}} i8 @test_flash_segment_ram
signed char test_flash_segment_ram(void) {
  const unsigned char *p = 0;
  // RAM = addrspace(0), segment -1
  // CHECK: ret i8 -1
  return __builtin_avr_flash_segment(p);
}
