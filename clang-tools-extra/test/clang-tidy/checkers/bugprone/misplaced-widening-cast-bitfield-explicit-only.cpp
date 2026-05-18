// RUN: %check_clang_tidy %s bugprone-misplaced-widening-cast %t -- \
// RUN:     -config="{CheckOptions: {bugprone-misplaced-widening-cast.CheckImplicitCasts: false}}" \
// RUN:     -- -target x86_64-unknown-unknown
// RUN: %check_clang_tidy %s bugprone-misplaced-widening-cast %t -- \
// RUN:     -config="{CheckOptions: {bugprone-misplaced-widening-cast.CheckImplicitCasts: false}}" \
// RUN:     -- -target i386-unknown-unknown

// Tests rely on specific type sizes:
// unsigned int = 32, unsigned short = 16, unsigned char = 8,
// unsigned long = 64, unsigned long long = 64 bits.

struct BitfieldHeader {
  unsigned long long field40 : 40;
  unsigned long field16 : 16;
};

// Source (unsigned short, 16-bit) == bit field width (16-bit). No warnings.
void explicit_cast_same_to_declared(unsigned short size) {
  struct BitfieldHeader h = {};
  h.field16 = (unsigned long)(size << 1);
}

void explicit_cast_same_to_bitfield(unsigned short size) {
  struct BitfieldHeader h = {};
  h.field16 = (unsigned short)(size << 1);
}

void explicit_cast_same_to_narrower(unsigned short size) {
  struct BitfieldHeader h = {};
  h.field16 = (unsigned char)(size << 1);
}

// Source (unsigned int, 32-bit) > bit field width (16-bit). Truncation, no warnings.
void explicit_cast_wider_to_declared(unsigned int size) {
  struct BitfieldHeader h = {};
  h.field16 = (unsigned long)(size << 1U);
}

void explicit_cast_wider_to_bitfield(unsigned int size) {
  struct BitfieldHeader h = {};
  h.field16 = (unsigned short)(size << 1U);
}

void explicit_cast_wider_to_narrower(unsigned int size) {
  struct BitfieldHeader h = {};
  h.field16 = (unsigned char)(size << 1U);
}

// Source (unsigned int, 32-bit) < bit field width (40-bit). Widening — should warn.
void explicit_cast_widen_shift(unsigned int size) {
  struct BitfieldHeader h = {};
  h.field40 = (unsigned long long)(size << 1U);
  // CHECK-MESSAGES: :[[@LINE-1]]:15: warning: either cast from 'unsigned int' to 'unsigned long long'
}

void explicit_cast_widen_multiply(unsigned int size) {
  struct BitfieldHeader h = {};
  h.field40 = (unsigned long long)(size * 2U);
  // CHECK-MESSAGES: :[[@LINE-1]]:15: warning: either cast from 'unsigned int' to 'unsigned long long'
}
