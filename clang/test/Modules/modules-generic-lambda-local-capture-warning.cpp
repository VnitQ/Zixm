// This test illustrates the spurious warning symptom of the bug.
// - In debug mode (asserts enabled), it fails with an assertion in
//   LocalInstantiationScope::findInstantiationOf.
// - In release mode (asserts disabled, e.g. -c opt), it successfully compiles
//   but fails the test because it emits a spurious uninitialized warning.
//
// RUN: rm -rf %t
// RUN: split-file %s %t
// RUN: cd %t
//
// RUN: %clang_cc1 -std=c++20 -fmodules -fno-implicit-modules \
// RUN:            -fmodules-local-submodule-visibility \
// RUN:            -fmodule-map-file=module.modulemap \
// RUN:            -fmodule-name=repro_module_a -emit-module \
// RUN:            -fmodules-embed-all-files -x c++ module.modulemap \
// RUN:            -Wuninitialized -Wuninitialized-const-reference \
// RUN:            -o repro_module_a.pcm
//
// RUN: %clang_cc1 -std=c++20 -fmodules -fno-implicit-modules \
// RUN:            -fmodules-local-submodule-visibility \
// RUN:            -fmodule-map-file=module.modulemap \
// RUN:            -fmodule-name=repro_wrapper_mock \
// RUN:            -fmodule-file=repro_module_a=repro_module_a.pcm \
// RUN:            -emit-module -fmodules-embed-all-files -x c++ module.modulemap \
// RUN:            -Wuninitialized -Wuninitialized-const-reference \
// RUN:            -o repro_wrapper_mock.pcm
//
// RUN: %clang_cc1 -std=c++20 -fmodules -fno-implicit-modules \
// RUN:            -fmodules-local-submodule-visibility \
// RUN:            -fmodule-map-file=module.modulemap \
// RUN:            -fmodule-name=repro \
// RUN:            -fmodule-file=repro_module_a=repro_module_a.pcm \
// RUN:            -fmodule-file=repro_wrapper_mock=repro_wrapper_mock.pcm \
// RUN:            -verify -Wuninitialized -Wuninitialized-const-reference -DEXTRA_DECL \
// RUN:            -fsyntax-only repro_main.cpp

//--- module.modulemap
module TemplateClassModule {
  textual header "template_class.h"
}
module repro_module_a {
  header "module_a.h"
  export *
  use TemplateClassModule
}
module repro_wrapper_mock {
  header "repro_wrapper.h"
  export *
  use repro_module_a
  use TemplateClassModule
}
module repro {
  export *
  use repro_wrapper_mock
}

//--- template_class.h
#ifndef TEMPLATE_CLASS_H_
#define TEMPLATE_CLASS_H_
namespace std {
template <typename T>
T&& move(T& t) noexcept { return static_cast<T&&>(t); }
}

enum class MyEnum { kValue1, kValue2 };
inline MyEnum GetLocalValue() { return MyEnum::kValue2; }

struct Pair { MyEnum first; MyEnum second; };
inline Pair GetLocalPair() { return Pair{MyEnum::kValue1, MyEnum::kValue2}; }

template <typename Stream, typename T>
void MockConsumer(Stream& strm, const T& val) {
  int x = 0;
}

template <typename T> struct RemovePointer { using type = T; };
template <typename T> struct RemovePointer<T*> { using type = T; };

template <typename Stream>
struct MockPrinter {
  Stream* strm;
  template <typename T>
  void operator()(const T& val) {
    MockConsumer(*strm, val);
  }
};

template <typename F>
struct MockDumpVars {
  F f;
  explicit MockDumpVars(F f) : f(std::move(f)) {}
  
  template <typename Stream>
  void DoStream(Stream& strm) const {
    f(&strm, 0, nullptr, nullptr, nullptr);
  }
};

template <typename F>
auto mock_make_dump_vars(F f) {
  return MockDumpVars<F>(std::move(f));
}

struct MockStream {};

template <typename F>
MockStream& operator<<(MockStream& strm, const MockDumpVars<F>& lazy) {
  lazy.DoStream(strm);
  return strm;
}

#define MOCK_DUMP_VARS(var) \
  mock_make_dump_vars([&](auto* _strm, const auto& _writer, \
                          const char* _fsep, const char* _kvsep, \
                          const char* const* _names) { \
    MockPrinter<typename RemovePointer<decltype(_strm)>::type>{_strm}(var); \
  })

template <typename T>
class TemplateClass {
 public:
  template <typename... Args>
  explicit TemplateClass(Args&&... args) {
#ifdef EXTRA_DECL
    const auto extra_var = 0;
#endif
    switch (const auto local_val = GetLocalValue(); local_val) {
      default:
        {
          MockStream strm;
          strm << MOCK_DUMP_VARS(local_val);
        }
    }
  }
};
#endif

//--- module_a.h
#pragma once
#include "template_class.h"

//--- repro_wrapper.h
#ifndef REPRO_WRAPPER_H_
#define REPRO_WRAPPER_H_
#include "template_class.h"
#include "module_a.h"
inline void TriggerInstantiation() {
  TemplateClass<void> p;
}
#endif

//--- repro_token.h
#ifndef REPRO_TOKEN_H_
#define REPRO_TOKEN_H_
#include "template_class.h"
#include "module_a.h"
template <typename... Ts>
struct MyOverload : Ts... {
  constexpr MyOverload(Ts... ts) : Ts(std::move(ts))... {}
};
template <typename... Ts>
MyOverload(Ts...) -> MyOverload<Ts...>;
inline auto my_lambda = [](int x) { return x; };
inline MyOverload visitor{my_lambda};

struct Token {
  void TriggerMethod() const {
    TemplateClass<int> p;
  }
};
#endif

//--- repro_main.cpp
// expected-no-diagnostics
#include "repro_wrapper.h"
#include "repro_token.h"
int main() {
  TriggerInstantiation();
  Token t;
  t.TriggerMethod();
}
