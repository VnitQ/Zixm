//===- MCInstrDescTest.cpp - MCInstrDesc unit tests -----------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/MC/MCInstrDesc.h"
#include "gtest/gtest.h"

using namespace llvm;

namespace {

TEST(MCInstrDescTest, PackedFields) {
  for (unsigned NumOperands : {0U, 1U, 125U, 129U, 130U}) {
    for (unsigned NumDefs : {0U, 1U, 126U, 128U}) {
      for (unsigned Size : {0U, 2U, 3U, 4U, 252U}) {
        MCInstrDesc Desc(65535, NumOperands, NumDefs, Size, 8191, 63, 63, 32767,
                         1023, (1ULL << MCID::Authenticated) | 1, UINT64_MAX);

        EXPECT_EQ(Desc.getOpcode(), 65535U);
        EXPECT_EQ(Desc.getNumOperands(), NumOperands);
        EXPECT_EQ(Desc.getNumDefs(), NumDefs);
        EXPECT_EQ(Desc.getSize(), Size);
        EXPECT_EQ(Desc.getSchedClass(), 8191U);
        EXPECT_EQ(Desc.NumImplicitUses, 63U);
        EXPECT_EQ(Desc.NumImplicitDefs, 63U);
        EXPECT_EQ(Desc.OpInfoOffset, 32767U);
        EXPECT_EQ(Desc.ImplicitOffset, 1023U);
        EXPECT_TRUE(Desc.isPreISelOpcode());
        EXPECT_TRUE(Desc.isAuthenticated());
        EXPECT_EQ(Desc.TSFlags, UINT64_MAX);
      }
    }
  }
}

} // namespace
