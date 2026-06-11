// RUN: %clang_cc1 -triple x86_64-unknown-unknown -ftrivial-auto-var-init=zero %s -emit-llvm -o - | FileCheck %s --check-prefix=ZERO
// RUN: %clang_cc1 -triple x86_64-unknown-unknown -ftrivial-auto-var-init=pattern %s -emit-llvm -o - | FileCheck %s --check-prefix=PATTERN

// Re-initializes the bypassed variable at the goto source. Per C6.2.4p6, the
// synthesized auto-init runs each time the declaration is reached, including
// via a backward jump.

// ZERO-LABEL: define {{.*}}@backward_goto_pointer(
// ZERO: BEGIN:
// ZERO: store ptr null, ptr %p, {{.*}}!annotation [[AUTO_INIT:!.+]]
// PATTERN-LABEL: define {{.*}}@backward_goto_pointer(
// PATTERN: BEGIN:
// PATTERN: store ptr inttoptr (i64 -6148914691236517206 to ptr), ptr %p, {{.*}}!annotation [[AUTO_INIT:!.+]]
int backward_goto_pointer(void) {
  int b = 0;
BEGIN:;
  int *p;
  if (b)
    *p = 10; // With zero-init, p is null on every pass, so *p traps.
  p = &b;
  if (!b) {
    b = 1;
    goto BEGIN;
  }
  return b;
}

// ZERO-LABEL: define {{.*}}@backward_goto_scalar(
// ZERO: BEGIN:
// ZERO: store i32 0, ptr %c, {{.*}}!annotation [[AUTO_INIT]]
// PATTERN-LABEL: define {{.*}}@backward_goto_scalar(
// PATTERN: BEGIN:
// PATTERN: store i32 -1431655766, ptr %c, {{.*}}!annotation [[AUTO_INIT]]
int backward_goto_scalar(void) {
  int b = 0;
BEGIN:;
  int c;
  if (b) return c;
  c = 5;
  b = 1;
  goto BEGIN;
}

// ZERO: [[AUTO_INIT]] = !{!"auto-init"}
// PATTERN: [[AUTO_INIT]] = !{!"auto-init"}
