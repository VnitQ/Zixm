// RUN: %clang_cc1 -triple x86_64-apple-macosx10.14.0 %s -verify -Werror

// Verify that the fortify dispatch for read/write/pread/pwrite/readlink/
// readlinkat/getcwd is gated on the full POSIX prototype: a user-defined
// function that happens to share a name with one of these libc functions but
// has a different signature must not be diagnosed as if it were the libc
// function. (Reviewer-reported regression: extern-C + arity match alone
// would falsely diagnose unrelated code under -Werror.)

typedef unsigned long size_t;
typedef long ssize_t;

// expected-no-diagnostics

// Variadic: prefix happens to match POSIX read, but the varargs make this
// an unrelated declaration.
ssize_t read(int, void *, size_t, ...);

void test_read_variadic(void) {
  char b[4];
  read(0, b, 8);
}

// Wrong return type (int) for write.
int write(int fd, const char *buf, size_t n);

void test_write_wrong_return(void) {
  char buf[4];
  write(0, buf, 8);
}

// Wrong return type (void) for readlink.
void readlink(const char *p, char *b, size_t n);

void test_readlink_wrong_return(void) {
  char b[4];
  readlink("/", b, 8);
}

// Wrong second parameter type (int instead of char*) for getcwd.
char *getcwd(int x, size_t n);

void test_getcwd_wrong_param(void) {
  getcwd(42, 8);
}

// pread64 with 'char *' buffer instead of POSIX 'void *'. Newlib-style
// syscall stubs commonly use this shape; the pointer-type mismatch trips
// the prototype gate.
int pread64(int, char *, size_t, long long);

void test_pread64_newlib_buffer(void) {
  char b[4];
  pread64(0, b, 8, 0);
}

// pwrite64 with 'const char *' instead of POSIX 'const void *': same shape.
int pwrite64(int, const char *, size_t, long long);

void test_pwrite64_newlib_buffer(void) {
  char b[4];
  pwrite64(0, b, 8, 0);
}
