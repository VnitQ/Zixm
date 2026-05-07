#include "Inputs/cuda.h"

// RUN: %clang_cc1 -triple nvptx64-nvidia-cuda -fclangir \
// RUN:            -fcuda-is-device -emit-cir -target-sdk-version=12.3 \
// RUN:            -I%S/Inputs/ %s -o %t.cir
// RUN: FileCheck --check-prefix=CIR-DEVICE --input-file=%t.cir %s

// RUN: %clang_cc1 -triple x86_64-unknown-linux-gnu -fclangir \
// RUN:            -x cuda -emit-cir -target-sdk-version=12.3 \
// RUN:            -I%S/Inputs/ %s -o %t.cir
// RUN: FileCheck --check-prefix=CIR-HOST --input-file=%t.cir %s

// __shared__ has shadows but they are not CUDA-runtime registered, so the
// `cu.var_registration` attribute must NOT be attached.
__shared__ int shared;
// CIR-HOST-NOT: @shared{{.*}}cu.var_registration

// __constant__ definition: registered as a Variable with the `constant` flag.
__constant__ int b;
// CIR-DEVICE: cir.global {{.*}}@b = #cir.int<0> : !s32i {{.*}}cu.var_registration = #cir.cu.var_registration<b, Variable, constant>
// CIR-HOST:   cir.global {{.*}}@b = #cir.poison : !s32i {{.*}}cu.var_registration = #cir.cu.var_registration<b, Variable, constant>

// Plain external __device__ declaration - no defining TU here, no registration
// (matches OG: extern shadow gets registered in the TU that defines it).
extern __device__ int ext_device_var;
// CIR-HOST-NOT:   @ext_device_var{{.*}}cu.var_registration
// CIR-DEVICE-NOT: @ext_device_var{{.*}}cu.var_registration

// Defining __device__: registered as Variable (no constant, no managed flag).
__device__ int dev_var = 1;
// CIR-DEVICE: cir.global {{.*}}@dev_var = #cir.int<1> : !s32i {{.*}}cu.var_registration = #cir.cu.var_registration<dev_var, Variable>
// CIR-HOST:   cir.global {{.*}}@dev_var = #cir.poison : !s32i {{.*}}cu.var_registration = #cir.cu.var_registration<dev_var, Variable>

// Plain host variable: must not carry a registration attribute.
int host_var;
// CIR-HOST-NOT: @host_var{{.*}}cu.var_registration
