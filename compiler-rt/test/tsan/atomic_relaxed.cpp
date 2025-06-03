// RUN: %clangxx_tsan -O1 %s -o %t

// RUN: TSAN_OPTIONS="relaxed_support=0" not %run %t 0 2>&1 | FileCheck %s --check-prefix=CHECK-OFF-0
// RUN: TSAN_OPTIONS="relaxed_support=0" not %run %t 1 2>&1 | FileCheck %s --check-prefix=CHECK-OFF-1
// RUN: TSAN_OPTIONS="relaxed_support=0" not %run %t 2 2>&1 | FileCheck %s --check-prefix=CHECK-OFF-2
// RUN: TSAN_OPTIONS="relaxed_support=0" not %run %t 3 2>&1 | FileCheck %s --check-prefix=CHECK-OFF-3
// RUN: TSAN_OPTIONS="relaxed_support=0" not %run %t 4 2>&1 | FileCheck %s --check-prefix=CHECK-OFF-4
// RUN: TSAN_OPTIONS="relaxed_support=0" not %run %t 5 2>&1 | FileCheck %s --check-prefix=CHECK-OFF-5
// RUN: TSAN_OPTIONS="relaxed_support=0" not %run %t 6 2>&1 | FileCheck %s --check-prefix=CHECK-OFF-6
// RUN: TSAN_OPTIONS="relaxed_support=0" not %run %t 7 2>&1 | FileCheck %s --check-prefix=CHECK-OFF-7
// RUN: TSAN_OPTIONS="relaxed_support=1"     %run %t 0 2>&1 | FileCheck %s --check-prefix=CHECK-ON
// RUN: TSAN_OPTIONS="relaxed_support=1"     %run %t 1 2>&1 | FileCheck %s --check-prefix=CHECK-ON
// RUN: TSAN_OPTIONS="relaxed_support=1"     %run %t 2 2>&1 | FileCheck %s --check-prefix=CHECK-ON
// RUN: TSAN_OPTIONS="relaxed_support=1"     %run %t 3 2>&1 | FileCheck %s --check-prefix=CHECK-ON
// RUN: TSAN_OPTIONS="relaxed_support=1"     %run %t 4 2>&1 | FileCheck %s --check-prefix=CHECK-ON
// RUN: TSAN_OPTIONS="relaxed_support=1"     %run %t 5 2>&1 | FileCheck %s --check-prefix=CHECK-ON
// RUN: TSAN_OPTIONS="relaxed_support=1"     %run %t 6 2>&1 | FileCheck %s --check-prefix=CHECK-ON
// RUN: TSAN_OPTIONS="relaxed_support=1"     %run %t 7 2>&1 | FileCheck %s --check-prefix=CHECK-ON
// RUN: TSAN_OPTIONS="relaxed_support=1"     %run %t 8 2>&1 | FileCheck %s --check-prefix=CHECK-ON
#include "test.h"

typedef long long T;
T atomic;
T data;

void Reset() {
  __atomic_store_n(&atomic, 1, __ATOMIC_RELEASE);
}

void* Reader(void* arg) {
  uintptr_t test = (uintptr_t) arg;
  volatile T sink = 0;
  if (test == 0) {
    do {
      sink = __atomic_load_n(&atomic, __ATOMIC_RELAXED);
    } while (sink == 0);
    __atomic_thread_fence(__ATOMIC_SEQ_CST);
  } else if (test == 1) {
    do {
      sink = __atomic_load_n(&atomic, __ATOMIC_RELAXED);
    } while (sink == 0);
    __atomic_thread_fence(__ATOMIC_ACQUIRE);
  } else if (test == 2) {
    do {
      sink = __atomic_load_n(&atomic, __ATOMIC_ACQUIRE);
    } while (sink == 0);
  }
  sink = data;
  return nullptr;
}

void* Writer(void* arg) {
  uintptr_t test = (uintptr_t) arg;
  data = 1;
  if (test == 0) {
    __atomic_thread_fence(__ATOMIC_SEQ_CST);
    __atomic_store_n(&atomic, 1, __ATOMIC_RELAXED);
  } else if (test == 1) {
    __atomic_thread_fence(__ATOMIC_RELEASE);
    __atomic_store_n(&atomic, 1, __ATOMIC_RELAXED);
  } else if (test == 2) {
    __atomic_store_n(&atomic, 1, __ATOMIC_RELEASE);
  }
  return nullptr;
}

int main(int argc, char *argv[]) {
  if (argc < 2) return 1;
  int test = atoi(argv[1]);
  uintptr_t writer = test / 3;
  uintptr_t reader = test % 3;
  pthread_t tr, tw;
  Reset();
  fprintf(stderr, "Test writer %zd reader %zd\n", writer, reader);
  pthread_create(&tw, nullptr, Writer, (void*) writer);
  pthread_create(&tr, nullptr, Reader, (void*) reader);
  pthread_join(tr, 0);
  pthread_join(tw, 0);
}

// CHECK-OFF-0: Test writer 0 reader 0
// CHECK-OFF-0: ThreadSanitizer: data race
// CHECK-OFF-0: ThreadSanitizer: reported
// CHECK-OFF-1: Test writer 0 reader 1
// CHECK-OFF-1: ThreadSanitizer: data race
// CHECK-OFF-1: ThreadSanitizer: reported
// CHECK-OFF-2: Test writer 0 reader 2
// CHECK-OFF-2: ThreadSanitizer: data race
// CHECK-OFF-2: ThreadSanitizer: reported
// CHECK-OFF-3: Test writer 1 reader 0
// CHECK-OFF-3: ThreadSanitizer: data race
// CHECK-OFF-3: ThreadSanitizer: reported
// CHECK-OFF-4: Test writer 1 reader 1
// CHECK-OFF-4: ThreadSanitizer: data race
// CHECK-OFF-4: ThreadSanitizer: reported
// CHECK-OFF-5: Test writer 1 reader 2
// CHECK-OFF-5: ThreadSanitizer: data race
// CHECK-OFF-5: ThreadSanitizer: reported
// CHECK-OFF-6: Test writer 2 reader 0
// CHECK-OFF-6: ThreadSanitizer: data race
// CHECK-OFF-6: ThreadSanitizer: reported
// CHECK-OFF-7: Test writer 2 reader 1
// CHECK-OFF-7: ThreadSanitizer: data race
// CHECK-OFF-7: ThreadSanitizer: reported
//
// CHECK-ON-NOT: WARNING: ThreadSanitizer: data race
// CHECK-ON-NOT: ThreadSanitizer: reported
