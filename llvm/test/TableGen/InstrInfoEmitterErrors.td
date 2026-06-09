// RUN: not llvm-tblgen -gen-instr-info -I %p/../../include %s 2>&1 | FileCheck %s

include "llvm/Target/Target.td"

def Reg : Register<"reg">;
def Regs : RegisterClass<"test", [i32], 0, (add Reg)>;

def TestInstrInfo : InstrInfo;
def TestTarget : Target {
  let InstructionSet = TestInstrInfo;
}

// CHECK: error: instruction size cannot be encoded in 7 bits
def InvalidSize : Instruction {
  let Namespace = "Test";
  let OutOperandList = (outs);
  let InOperandList = (ins);
  let AsmString = "";
  let Size = 254;
}
