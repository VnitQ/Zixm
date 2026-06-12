! ; Check that -flto=thin without -fsplit-lto-unit has EnableSplitLTOUnit = 0
! RUN: %flang -flto=thin  -c -o - %s | llvm-dis | FileCheck %s
! RUN: %flang -flto=thin -c -o - %s | llvm-dis | FileCheck %s
! RUN: %flang -flto=thin --target=x86_64-linux-gnu -c -o - %s | llvm-dis | FileCheck %s
! CHECK: !{i32 1, !"EnableSplitLTOUnit", i32 0}
!
! ; Check that -flto=thin with -fsplit-lto-unit has EnableSplitLTOUnit = 1
! RUN: %flang -flto=thin -fsplit-lto-unit -c -o - %s | llvm-dis | FileCheck %s --check-prefix=SPLIT
! RUN: %flang -flto=thin --target=x86_64-linux-gnu -fsplit-lto-unit -c -o - %s | llvm-dis | FileCheck %s --check-prefix=SPLIT
! SPLIT: !{i32 1, !"EnableSplitLTOUnit", i32 1}
!
! ; Check that regular LTO has EnableSplitLTOUnit = 1
! RUN: %flang -flto -c -o - %s | llvm-dis | FileCheck %s --implicit-check-not="EnableSplitLTOUnit" --check-prefix=SPLIT
! RUN: %flang -flto --target=x86_64-linux-gnu -c -o - %s | llvm-dis | FileCheck %s --implicit-check-not="EnableSplitLTOUnit" --check-prefix=SPLIT

! ; Check that regular LTO has no EnableSplitLTOUnit = 1 for apple targets
! RUN: %flang -flto --target=x86_64-apple-macosx -c -o - %s | llvm-dis | not FileCheck %s --implicit-check-not="EnableSplitLTOUnit" --check-prefix=SPLIT

program main
end program main
