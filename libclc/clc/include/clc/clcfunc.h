//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef __CLC_CLCFUNC_H_
#define __CLC_CLCFUNC_H_

#define _CLC_OVERLOAD __attribute__((overloadable))
#define _CLC_DECL

// Force inlining of helpers for SPIR-V targets, which are built at -O0 and
// never run through 'opt'.
#if defined(CLC_SPIRV)
#define _CLC_INLINE __attribute__((always_inline)) inline
#else
#define _CLC_INLINE inline
#endif

#define _CLC_CONST __attribute__((const))

#if defined(__VULKAN__)
#define _CLC_DEF __attribute__((noinline)) __attribute__((clspv_libclc_builtin))
#elif defined(CLC_SPIRV)
#define _CLC_DEF __attribute__((always_inline))
#else
#define _CLC_DEF
#endif

#if __OPENCL_C_VERSION__ == CL_VERSION_2_0 ||                                  \
    (__OPENCL_C_VERSION__ >= CL_VERSION_3_0 &&                                 \
     defined(__opencl_c_generic_address_space))
#define _CLC_GENERIC_AS_SUPPORTED 1
#if __CLC_PRIVATE_ADDRSPACE_VAL != __CLC_GENERIC_ADDRSPACE_VAL
#define _CLC_DISTINCT_GENERIC_AS_SUPPORTED 1
#else
#define _CLC_DISTINCT_GENERIC_AS_SUPPORTED 0
#endif
#else
#define _CLC_GENERIC_AS_SUPPORTED 0
#define _CLC_DISTINCT_GENERIC_AS_SUPPORTED 0
#endif

#endif // __CLC_CLCFUNC_H_
