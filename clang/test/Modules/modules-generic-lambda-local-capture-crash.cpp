// This test illustrates the compiler assertion/crash symptom of the bug.
// - In debug mode (asserts enabled), it fails with an assertion in
//   LocalInstantiationScope::findInstantiationOf.
// - In release mode (asserts disabled, e.g. -c opt), it fails with a compiler
//   segmentation fault (SIGSEGV) during compilation.
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
// RUN:            -o repro_module_a.pcm
//
// RUN: %clang_cc1 -std=c++20 -fmodules -fno-implicit-modules \
// RUN:            -fmodules-local-submodule-visibility \
// RUN:            -fmodule-map-file=module.modulemap \
// RUN:            -fmodule-name=repro_wrapper_mock \
// RUN:            -fmodule-file=repro_module_a=repro_module_a.pcm \
// RUN:            -emit-module -fmodules-embed-all-files -x c++ module.modulemap \
// RUN:            -o repro_wrapper_mock.pcm
//
// RUN: %clang_cc1 -std=c++20 -fmodules -fno-implicit-modules \
// RUN:            -fmodules-local-submodule-visibility \
// RUN:            -fmodule-map-file=module.modulemap \
// RUN:            -fmodule-name=repro \
// RUN:            -fmodule-file=repro_module_a=repro_module_a.pcm \
// RUN:            -fmodule-file=repro_wrapper_mock=repro_wrapper_mock.pcm \
// RUN:            -verify -fsyntax-only repro_main.cpp

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

template <typename T>
struct Consumer {
  template <typename U>
  void operator()(const U& x) const {}
};

template <typename F>
struct Holder {
  F f;
  explicit Holder(F f) : f(std::move(f)) {}
  void call() const { f(0); }
};

template <typename F>
auto make_holder(F f) {
  return Holder<F>(std::move(f));
}

template <typename T>
class TemplateClass {
 public:
  template <typename... Args>
  explicit TemplateClass(Args&&... args);
};

template <typename T>
template <typename... Args>
TemplateClass<T>::TemplateClass(Args&&... args) {
  const auto local_val = GetLocalValue();
  const auto [a, b] = GetLocalPair();
  auto holder = make_holder([&](auto x) {
    Consumer<decltype(x)>{}(local_val);
    Consumer<decltype(x)>{}(a);
  });
  holder.call();
}
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
    TemplateClass<void> p(*this);
  }
};
#endif

//--- repro_main.cpp
// expected-no-diagnostics
#include "repro_wrapper.h"
#include "repro_token.h"
int main() {
  Token t;
  t.TriggerMethod();
}
