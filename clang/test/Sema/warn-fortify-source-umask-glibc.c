// RUN: %clang_cc1 -triple x86_64-unknown-linux-gnu %s -verify

// Verify the fortify gate accepts a glibc-style declaration of umask
// whose prototype is written in terms of the internal __mode_t typedef
// (not mode_t directly). Earlier versions of this check matched on the
// `mode_t` typedef name and silently failed to fire on glibc.

#include "Inputs/warn-fortify-source-umask-glibc.h"

void call_umask_glibc(mode_t runtime_mode) {
  umask(0);
  umask(0644);
  umask(01000);   // expected-warning {{'umask' argument sets non-file-permission bits (01000); those bits are ignored}}
  umask(0xFFFF);  // expected-warning {{'umask' argument sets non-file-permission bits (0177000); those bits are ignored}}
  umask(runtime_mode); // no warning, not a constant
}
