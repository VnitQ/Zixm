// RUN: %clang_cc1 -triple x86_64-apple-macosx10.14.0 %s -verify
// expected-no-diagnostics

// User-defined umask declared in user code (not a system header). The
// fortify gate requires the resolved function to have at least one
// declaration in a system header, so no -Wfortify-source warning fires.

extern int umask(int);

void call_user_umask(void) {
  (void)umask(01000);
  (void)umask(0xFFFF);
  (void)umask(7777);
}
