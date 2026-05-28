//===-- Compile time enabling of stict floating-point behavior --*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIBC_SRC___SUPPORT_MACROS_PROPERTIES_FENV_SUPPORT_H
#define LLVM_LIBC_SRC___SUPPORT_MACROS_PROPERTIES_FENV_SUPPORT_H

#include "src/__support/macros/properties/architectures.h"
#include "src/__support/macros/properties/compiler.h"

// Check target support of strict floating-point behavior
#if defined(LIBC_TARGET_ARCH_IS_X86_64) ||                                     \
    defined(LIBC_TARGET_ARCH_IS_AARCH64) ||                                    \
    defined(LIBC_TARGET_ARCH_IS_ARM) ||                                        \
    defined(LIBC_TARGET_ARCH_IS_RISCV64) ||                                    \
    defined(LIBC_TARGET_ARCH_IS_RISCV32) ||                                    \
    defined(LIBC_TARGET_ARCH_IS_SYSTEMZ) ||                                    \
    defined(LIBC_TARGET_ARCH_IS_LOONGARCH64)
#define LIBC_TARGET_HAS_STRICT_FP
#endif

// Enable strict floating-point behavior on supported targets
#ifdef LIBC_TARGET_HAS_STRICT_FP
#if defined(LIBC_COMPILER_IS_CLANG) && LIBC_COMPILER_CLANG_VER > 10
// Clang >= 10 supports `#pragma clang fp exceptions(maytrap)`, which is the
// local-scope equivalent of `-ffp-exception-behavior=maytrap` and is what the
// -Wfenv-access diagnostic recommends.
#define LIBC_FENV_ACCESS_ON _Pragma("clang fp exceptions(maytrap)")
#else
// Portable fallback for GCC, MSVC, or older clang.
#define LIBC_FENV_ACCESS_ON _Pragma("STDC FENV_ACCESS ON")
#endif
#else
#define LIBC_FENV_ACCESS_ON
#endif

#endif
