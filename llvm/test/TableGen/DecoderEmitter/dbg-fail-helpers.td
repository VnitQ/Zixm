// RUN: llvm-tblgen -gen-disassembler -I %p/../../../include %s | FileCheck %s

// Verify the DecoderEmitter emits the dbgFailOpd / dbgFailInsn helpers used
// by per-operand and whole-instruction decode debug logging.

include "llvm/Target/Target.td"

def R0 : Register<"r0">;
def RC : RegisterClass<"MyTarget", [i32], 32, (add R0)>;

def MyInstrInfo : InstrInfo;

def MyTarget : Target {
  let InstructionSet = MyInstrInfo;
}

def I : Instruction {
  let OutOperandList = (outs RC:$dst);
  let InOperandList = (ins);
  let Size = 4;
  bits<32> Inst;
  bits<4> dst;
  let Inst{3...0} = dst;
  let Inst{31...4} = 0;
}

// dbgFailOpd: per-operand check-site helper.
// CHECK:      DecodeStatus dbgFailOpd(const char *Op, const char *Desc, const char *Decoder,
// CHECK-NEXT:                         bool *DecodeComplete = nullptr) {
// CHECK-NEXT:   LLVM_DEBUG(dbgs() << "OPC_Decode for " << Op << ": " << Desc << " using "
// CHECK-NEXT:                     << Decoder << " : FAIL\n");
// CHECK-NEXT:   if (DecodeComplete)
// CHECK-NEXT:     *DecodeComplete = false;
// CHECK-NEXT:   return MCDisassembler::Fail;
// CHECK-NEXT: }

// dbgFailInsn: whole-instruction custom-decoder check-site helper.
// CHECK{LITERAL}: [[maybe_unused]] DecodeStatus dbgFailInsn(const char *Name, const char *Decoder,
// CHECK-NEXT:                                           bool *DecodeComplete = nullptr) {
// CHECK-NEXT:   LLVM_DEBUG(dbgs() << "OPC_Decode for " << Name << ": insn using " << Decoder
// CHECK-NEXT:                     << " : FAIL\n");
// CHECK-NEXT:   if (DecodeComplete)
// CHECK-NEXT:     *DecodeComplete = false;
// CHECK-NEXT:   return MCDisassembler::Fail;
// CHECK-NEXT: }

// And the per-operand check site inside decodeToMCInst calls dbgFailOpd
// with the operand name, field description, and decoder-method name as
// separate string-literal arguments.
// CHECK-LABEL: static DecodeStatus decodeToMCInst(
// CHECK:       case 0:
// CHECK-NEXT:    tmp = fieldFromInstruction(insn, 0, 4);
// CHECK-NEXT:    if (!Check(S, DecodeRCRegisterClass(MI, tmp, Address, Decoder))) return dbgFailOpd("dst", "field(0,4)", "DecodeRCRegisterClass");
// CHECK-NEXT:    return S;
