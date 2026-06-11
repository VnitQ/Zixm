// REQUIRES: webassembly-registered-target
// RUN: %clang_cc1 -triple wasm32-unknown-unknown -emit-llvm -O0 -fwasm-fix-function-bitcasts -o - %s | FileCheck %s

// Test runtime function pointer cast with different argument counts
// This simulates cases like g_list_free_full where a function pointer parameter
// is cast from fewer params to more params

typedef void (*OneArgFunc)(void *);
typedef void (*TwoArgFunc)(void *, void *);

// CHECK: @__wasm_runtime_wrapper_vi_to_vii_fptr = internal thread_local global ptr null

// A function with one argument
void my_one_arg_func(void *ptr) {
  // Do something
}

// Test case 1: Direct call of casted runtime function pointer
// CHECK-LABEL: @runtime_cast_caller
void runtime_cast_caller(OneArgFunc fp, void *data) {
  // Cast the runtime parameter from 1-arg to 2-arg signature and call directly
  // CHECK: store ptr %{{.*}}, ptr @__wasm_runtime_wrapper_vi_to_vii_fptr
  // CHECK: call void @__wasm_runtime_wrapper_vi_to_vii(ptr
  ((TwoArgFunc)fp)(data, (void*)0);
}

// The runtime wrapper should be generated once and shared by both cases
// CHECK-LABEL: define linkonce_odr void @__wasm_runtime_wrapper_vi_to_vii(ptr %0, ptr %1)
// CHECK: %{{.*}} = load ptr, ptr @__wasm_runtime_wrapper_vi_to_vii_fptr
// CHECK: call void %{{.*}}(ptr %0)
// CHECK: ret void

// Test case 2: Pass casted runtime function pointer to another function
// This is closer to the real g_list_free_full scenario
// CHECK-LABEL: @library_function
void library_function(TwoArgFunc func, void *data) {
  // CHECK: call void %{{.*}}(ptr noundef %{{.*}}, ptr noundef null)
  func(data, (void*)0);
}

// CHECK-LABEL: @indirect_caller
void indirect_caller(OneArgFunc fp, void *data) {
  // Cast and pass to another function (like g_list_free_full does)
  // CHECK: store ptr %{{.*}}, ptr @__wasm_runtime_wrapper_vi_to_vii_fptr
  // CHECK: call void @library_function(ptr noundef @__wasm_runtime_wrapper_vi_to_vii
  library_function((TwoArgFunc)fp, data);
}

// CHECK-LABEL: @test
void test() {
  // Test both scenarios
  runtime_cast_caller(my_one_arg_func, (void*)0);
  indirect_caller(my_one_arg_func, (void*)0);
}
