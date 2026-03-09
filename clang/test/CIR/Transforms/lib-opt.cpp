// RUN: %clang_cc1 -fclangir -O1 -emit-cir -mmlir --mlir-print-ir-after-all -clangir-lib-opt=all %s -o - | FileCheck %s -check-prefix=CIR
// CIR: IR Dump After LibOpt (cir-lib-opt)
