// Based on clang/test/CodeGenCUDA/device-stub.cu (incubator).

// Create a dummy GPU binary file for registration.
// RUN: echo -n "GPU binary would be here." > %t

// RUN: %clang_cc1 -triple x86_64-linux-gnu -emit-cir %s -x cuda \
// RUN:   -target-sdk-version=12.3 -fcuda-include-gpubinary %t -o %t.cir
// RUN: FileCheck --input-file=%t.cir %s --check-prefix=CIR

// RUN: %clang_cc1 -triple x86_64-linux-gnu -fclangir -emit-llvm %s -x cuda \
// RUN:   -target-sdk-version=12.3 -fcuda-include-gpubinary %t -o %t-cir.ll
// RUN: FileCheck --input-file=%t-cir.ll %s --check-prefix=LLVM

// RUN: %clang_cc1 -triple x86_64-linux-gnu -emit-llvm %s -x cuda \
// RUN:   -target-sdk-version=12.3 -fcuda-include-gpubinary %t -o %t.ll
// RUN: FileCheck --input-file=%t.ll %s --check-prefix=OGCG

// RUN: %clang_cc1 -triple x86_64-linux-gnu -emit-cir %s -x cuda \
// RUN:   -target-sdk-version=12.3 -o %t.nogpu.cir
// RUN: FileCheck --input-file=%t.nogpu.cir %s --check-prefix=NOGPUBIN

#include "Inputs/cuda.h"

__global__ void kernelfunc(int i, int j, int k) {}

void hostfunc(void) { kernelfunc<<<1, 1>>>(1, 1, 1); }

// Device-side shadows: exercise the __cudaRegisterVar code path alongside the
// existing __cudaRegisterFunction kernel registration.
__device__ int a;
__constant__ int b;

// Check module constructor is registered in module attributes.
// CIR: cir.global_ctors = [#cir.global_ctor<"__cuda_module_ctor", 65535>]

// Check runtime function declarations.
// CIR: cir.func private @atexit(!cir.ptr<!cir.func<()>>) -> !s32i
// CIR: cir.func private @__cudaUnregisterFatBinary(!cir.ptr<!cir.ptr<!void>>)

// Check the module destructor body: load handle and call UnregisterFatBinary.
// CIR: cir.func internal private @__cuda_module_dtor()
// CIR-NEXT: %[[HANDLE_ADDR:.*]] = cir.get_global @__cuda_gpubin_handle
// CIR-NEXT: %[[HANDLE:.*]] = cir.load %[[HANDLE_ADDR]]
// CIR-NEXT: cir.call @__cudaUnregisterFatBinary(%[[HANDLE]])
// CIR-NEXT: cir.return

// CIR: cir.func private @__cudaRegisterFatBinaryEnd(!cir.ptr<!cir.ptr<!void>>)

// __cudaRegisterVar runtime declaration and per-variable name strings for
// device shadows. These are emitted between __cudaRegisterFatBinaryEnd and
// __cudaRegisterFunction; relative order is not significant.
// CIR-DAG: cir.func private @__cudaRegisterVar(!cir.ptr<!cir.ptr<!void>>, !cir.ptr<!void>, !cir.ptr<!void>, !cir.ptr<!void>, !s32i, !u64i, !s32i, !s32i)
// CIR-DAG: cir.global "private" constant cir_private @".stra" = #cir.const_array<"a" : !cir.array<!u8i x 2>, trailing_zeros>
// CIR-DAG: cir.global "private" constant cir_private @".strb" = #cir.const_array<"b" : !cir.array<!u8i x 2>, trailing_zeros>

// Check the __cudaRegisterFunction runtime declaration:
//   int __cudaRegisterFunction(void**, void*, void*, void*, int,
//                              void*, void*, void*, void*, void*)
// CIR: cir.func private @__cudaRegisterFunction(!cir.ptr<!cir.ptr<!void>>, !cir.ptr<!void>, !cir.ptr<!void>, !cir.ptr<!void>, !s32i, !cir.ptr<!void>, !cir.ptr<!void>, !cir.ptr<!void>, !cir.ptr<!void>, !cir.ptr<!void>) -> !s32i

// Check the device-side name string for kernelfunc (mangled, null-terminated).
// CIR: cir.global "private" constant cir_private @".str_Z10kernelfunciii" = #cir.const_array<"_Z10kernelfunciii" : !cir.array<!u8i x 18>, trailing_zeros> : !cir.array<!u8i x 18>

// Check __cuda_register_globals body: __cudaRegisterFunction for each kernel,
// then __cudaRegisterVar for each device shadow.
// CIR: cir.func internal private @__cuda_register_globals(%[[FATBIN:.*]]: !cir.ptr<!cir.ptr<!void>>
// CIR-NEXT: %[[NULL:.*]] = cir.const #cir.ptr<null> : !cir.ptr<!void>
// CIR-NEXT: %[[STR_ADDR:.*]] = cir.get_global @".str_Z10kernelfunciii"
// CIR-NEXT: %[[DEVICE_FUNC:.*]] = cir.cast bitcast %[[STR_ADDR]]
// CIR-NEXT: %[[HOST_FUNC_RAW:.*]] = cir.get_global @{{.*}}kernelfunc{{.*}}
// CIR-NEXT: %[[HOST_FUNC:.*]] = cir.cast bitcast %[[HOST_FUNC_RAW]]
// CIR-NEXT: %[[THREAD_LIMIT:.*]] = cir.const #cir.int<-1> : !s32i
// CIR-NEXT: cir.call @__cudaRegisterFunction(%{{.*}}, %[[HOST_FUNC]], %[[DEVICE_FUNC]], %[[DEVICE_FUNC]], %[[THREAD_LIMIT]], %[[NULL]], %[[NULL]], %[[NULL]], %[[NULL]], %[[NULL]])
// Registration for __device__ int a (constant=0):
// CIR: %[[#NAMEA_RAW:]] = cir.get_global @".stra"
// CIR-NEXT: %[[#NAMEA:]] = cir.cast bitcast %[[#NAMEA_RAW]]
// CIR-NEXT: %[[#HOSTA_RAW:]] = cir.get_global @a
// CIR-NEXT: %[[#HOSTA:]] = cir.cast bitcast %[[#HOSTA_RAW]]
// CIR-NEXT: %[[#EXTA:]] = cir.const #cir.int<0> : !s32i
// CIR-NEXT: %[[#SZA:]] = cir.const #cir.int<4> : !u64i
// CIR-NEXT: %[[#CONA:]] = cir.const #cir.int<0> : !s32i
// CIR-NEXT: %[[#NORMA:]] = cir.const #cir.int<0> : !s32i
// CIR-NEXT: cir.call @__cudaRegisterVar(%[[FATBIN]], %[[#HOSTA]], %[[#NAMEA]], %[[#NAMEA]], %[[#EXTA]], %[[#SZA]], %[[#CONA]], %[[#NORMA]])
// Registration for __constant__ int b (constant=1):
// CIR: %[[#NAMEB_RAW:]] = cir.get_global @".strb"
// CIR-NEXT: %[[#NAMEB:]] = cir.cast bitcast %[[#NAMEB_RAW]]
// CIR-NEXT: %[[#HOSTB_RAW:]] = cir.get_global @b
// CIR-NEXT: %[[#HOSTB:]] = cir.cast bitcast %[[#HOSTB_RAW]]
// CIR-NEXT: %[[#EXTB:]] = cir.const #cir.int<0> : !s32i
// CIR-NEXT: %[[#SZB:]] = cir.const #cir.int<4> : !u64i
// CIR-NEXT: %[[#CONB:]] = cir.const #cir.int<1> : !s32i
// CIR-NEXT: %[[#NORMB:]] = cir.const #cir.int<0> : !s32i
// CIR-NEXT: cir.call @__cudaRegisterVar(%[[FATBIN]], %[[#HOSTB]], %[[#NAMEB]], %[[#NAMEB]], %[[#EXTB]], %[[#SZB]], %[[#CONB]], %[[#NORMB]])
// CIR-NEXT: cir.return

// CIR: cir.global "private" constant cir_private @__cuda_fatbin_str = #cir.const_array<"GPU binary would be here." : !cir.array<!u8i x 25>> : !cir.array<!u8i x 25> {alignment = 8 : i64, section = ".nv_fatbin"}

// Check the fatbin wrapper struct: { magic, version, ptr to fatbin, null }, with section.
// CIR: cir.global constant cir_private @__cuda_fatbin_wrapper = #cir.const_record<{
// CIR-SAME: #cir.int<1180844977> : !s32i,
// CIR-SAME: #cir.int<1> : !s32i,
// CIR-SAME: #cir.global_view<@__cuda_fatbin_str> : !cir.ptr<!void>,
// CIR-SAME: #cir.ptr<null> : !cir.ptr<!void>
// CIR-SAME: }> : !rec_anon_struct {section = ".nvFatBinSegment"}

// Check the GPU binary handle global.
// CIR: cir.global "private" internal @__cuda_gpubin_handle = #cir.ptr<null> : !cir.ptr<!cir.ptr<!void>>

// CIR: cir.func private @__cudaRegisterFatBinary(!cir.ptr<!void>) -> !cir.ptr<!cir.ptr<!void>>

// Check the module constructor body: register fatbin, store handle,
// call __cuda_register_globals, call RegisterFatBinaryEnd (CUDA >= 10.1),
// then register dtor with atexit.
// CIR: cir.func internal private @__cuda_module_ctor()
// CIR-NEXT: %[[WRAPPER:.*]] = cir.get_global @__cuda_fatbin_wrapper
// CIR-NEXT: %[[VOID_PTR:.*]] = cir.cast bitcast %[[WRAPPER]]
// CIR-NEXT: %[[RET:.*]] = cir.call @__cudaRegisterFatBinary(%[[VOID_PTR]])
// CIR-NEXT: %[[HANDLE_ADDR:.*]] = cir.get_global @__cuda_gpubin_handle
// CIR-NEXT: cir.store %[[RET]], %[[HANDLE_ADDR]]
// CIR-NEXT: cir.call @__cuda_register_globals(%[[RET]])
// CIR-NEXT: cir.call @__cudaRegisterFatBinaryEnd(%[[RET]])
// CIR-NEXT: %[[DTOR_PTR:.*]] = cir.get_global @__cuda_module_dtor
// CIR-NEXT: {{.*}} = cir.call @atexit(%[[DTOR_PTR]])
// CIR-NEXT: cir.return

// OGCG: constant [25 x i8] c"GPU binary would be here.", section ".nv_fatbin", align 8
// OGCG: @__cuda_fatbin_wrapper = internal constant { i32, i32, ptr, ptr } { i32 1180844977, i32 1, ptr @{{.*}}, ptr null }, section ".nvFatBinSegment"
// OGCG: @__cuda_gpubin_handle = internal global ptr null
// OGCG: @llvm.global_ctors = appending global {{.*}}@__cuda_module_ctor

// OGCG: define internal void @__cuda_register_globals(ptr %[[#OGFATBIN:]])
// OGCG: call{{.*}}__cudaRegisterFunction(ptr %[[#OGFATBIN]], {{.*}}kernelfunc{{.*}}
// OGCG: call void @__cudaRegisterVar(ptr %[[#OGFATBIN]], ptr @a, {{.*}}, {{.*}}, i32 0, i64 4, i32 0, i32 0)
// OGCG: call void @__cudaRegisterVar(ptr %[[#OGFATBIN]], ptr @b, {{.*}}, {{.*}}, i32 0, i64 4, i32 1, i32 0)
// OGCG: ret void

// OGCG: define internal void @__cuda_module_ctor
// OGCG: call{{.*}}__cudaRegisterFatBinary(ptr @__cuda_fatbin_wrapper)
// OGCG: store ptr %{{.*}}, ptr @__cuda_gpubin_handle
// OGCG-NEXT: call void @__cuda_register_globals
// OGCG: call i32 @atexit(ptr @__cuda_module_dtor)

// OGCG: define internal void @__cuda_module_dtor
// OGCG: load ptr, ptr @__cuda_gpubin_handle
// OGCG: call void @__cudaUnregisterFatBinary

// LLVM: constant [25 x i8] c"GPU binary would be here.", section ".nv_fatbin", align 8
// LLVM: @__cuda_fatbin_wrapper = {{.*}}constant { i32, i32, ptr, ptr } { i32 1180844977, i32 1, ptr @{{.*}}, ptr null }, section ".nvFatBinSegment"
// LLVM: @__cuda_gpubin_handle = internal global ptr null
// LLVM: @llvm.global_ctors = appending global {{.*}}@__cuda_module_ctor

// LLVM: define internal void @__cuda_module_dtor
// LLVM: load ptr, ptr @__cuda_gpubin_handle
// LLVM: call void @__cudaUnregisterFatBinary

// LLVM: define internal void @__cuda_register_globals(ptr %[[#FATBIN:]])
// LLVM: call{{.*}}@__cudaRegisterFunction(ptr %[[#FATBIN]], ptr @{{.*}}kernelfunc{{.*}}, ptr @{{.*}}, ptr @{{.*}}, i32 -1, ptr null, ptr null, ptr null, ptr null, ptr null)
// LLVM: call void @__cudaRegisterVar(ptr %[[#FATBIN]], ptr @a, ptr @.stra, ptr @.stra, i32 0, i64 4, i32 0, i32 0)
// LLVM: call void @__cudaRegisterVar(ptr %[[#FATBIN]], ptr @b, ptr @.strb, ptr @.strb, i32 0, i64 4, i32 1, i32 0)
// LLVM: ret void

// LLVM: define internal void @__cuda_module_ctor
// LLVM: call{{.*}}@__cudaRegisterFatBinary(ptr @__cuda_fatbin_wrapper)
// LLVM: store ptr %{{.*}}, ptr @__cuda_gpubin_handle
// LLVM-NEXT: call void @__cuda_register_globals
// LLVM: call i32 @atexit(ptr @__cuda_module_dtor)

// No GPU binary — no registration infrastructure at all.
// NOGPUBIN-NOT: fatbin
// NOGPUBIN-NOT: gpubin
// NOGPUBIN-NOT: __cuda_register_globals
// NOGPUBIN-NOT: __cuda_module_ctor
// NOGPUBIN-NOT: __cuda_module_dtor
