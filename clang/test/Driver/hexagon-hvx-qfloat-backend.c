// ---------------------------------------------------------------------------
// Tests for the hvx qfloat modes backend flag.
// ---------------------------------------------------------------------------

// Test for correct backend flag with case-insensitive values.
// CHECK-STRICT-IEEE: "-mllvm" "-hexagon-qfloat-mode=strict-ieee"
// RUN: %clang -c %s -### -target hexagon-unknown-elf -mv79 -mhvx \
// RUN:   -mhvx-qfloat=strict-ieee 2>&1 | FileCheck -check-prefix=CHECK-STRICT-IEEE %s
// RUN: %clang -c %s -### -target hexagon-unknown-elf -mv79 -mhvx \
// RUN:   -mhvx-qfloat=sTriCt-Ieee 2>&1 | FileCheck -check-prefix=CHECK-STRICT-IEEE %s

// CHECK-IEEE: "-mllvm" "-hexagon-qfloat-mode=ieee"
// RUN: %clang -c %s -### -target hexagon-unknown-elf -mv79 -mhvx \
// RUN:   -mhvx-qfloat=ieee 2>&1 | FileCheck -check-prefix=CHECK-IEEE %s
// RUN: %clang -c %s -### -target hexagon-unknown-elf -mv79 -mhvx \
// RUN:   -mhvx-qfloat=IEEE 2>&1 | FileCheck -check-prefix=CHECK-IEEE %s

// CHECK-LOSSY: "-mllvm" "-hexagon-qfloat-mode=lossy"
// RUN: %clang -c %s -### -target hexagon-unknown-elf -mv79 -mhvx \
// RUN:   -mhvx-qfloat=lossy 2>&1 | FileCheck -check-prefix=CHECK-LOSSY %s
// RUN: %clang -c %s -### -target hexagon-unknown-elf -mv79 -mhvx \
// RUN:   -mhvx-qfloat=lOSSy 2>&1 | FileCheck -check-prefix=CHECK-LOSSY %s

// CHECK-LEGACY: "-mllvm" "-hexagon-qfloat-mode=legacy"
// RUN: %clang -c %s -### -target hexagon-unknown-elf -mv79 -mhvx \
// RUN:   -mhvx-qfloat=legacy 2>&1 | FileCheck -check-prefix=CHECK-LEGACY %s
// RUN: %clang -c %s -### -target hexagon-unknown-elf -mv79 -mhvx \
// RUN:   -mhvx-qfloat=LEGacy 2>&1 | FileCheck -check-prefix=CHECK-LEGACY %s

// Test for default mode, if no mode is specified on v79.
// RUN: %clang -c %s -### -target hexagon-unknown-elf -mv79 -mhvx \
// RUN:   -mhvx-qfloat 2>&1 | FileCheck -check-prefix=CHECK-LOSSY %s

// Test for arches lower than v79 does not pass any backend flag.
// CHECK-MODE-NOT: "-mllvm" "-hexagon-qfloat-mode="
// RUN: %clang -c %s -### -target hexagon-unknown-elf -mv75 -mhvx \
// RUN:   -mhvx-qfloat 2>&1 | FileCheck -check-prefix=CHECK-MODE %s

// Test for arches lower than v79 warns that qfloat mode is ignored.
// CHECK-MODE-WARN: warning: ignoring 'ieee' in '-mhvx-qfloat=ieee' option as it is not currently supported for target 'HVX v75'
// CHECK-MODE-WARN-NOT: "-mllvm" "-hexagon-qfloat-mode="
// RUN: %clang -c %s -### -target hexagon-unknown-elf -mv75 -mhvx \
// RUN:   -mhvx-qfloat=ieee 2>&1 | FileCheck -check-prefix=CHECK-MODE-WARN %s
