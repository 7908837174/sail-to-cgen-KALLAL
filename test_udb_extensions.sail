default Order dec

$include <prelude.sail>

/* Test case for UDB extension identification (Issue #307)
   Tests the new extension metadata system that identifies UDB-defined extensions
   in the schema instead of hardcoding names in Ruby code.
*/

// ============================================================================
// UDB-DEFINED EXTENSIONS (should be automatically detected)
// ============================================================================

// Zicsr extension - Control and Status Register Instructions
register UDB_Zicsr_mstatus : bits(64)
register UDB_Zicsr_mie : bits(64)

enum Zicsr_csr_ops = {CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI}

union Zicsr_ast = {
  CSRRW : (bits(12), regbits, regbits),
  CSRRS : (bits(12), regbits, regbits),
  CSRRC : (bits(12), regbits, regbits)
}

bitfield Zicsr_instruction : bits(32) = {
  opcode : 6..0,
  rd     : 11..7,
  funct3 : 14..12,
  rs1    : 19..15,
  csr    : 31..20
}

// Zifencei extension - Instruction-Fetch Fence
register UDB_Zifencei_config : bits(32)

enum Zifencei_ops = {FENCE_I}

union Zifencei_ast = {
  FENCE_I : unit
}

// Zba extension - Address Generation Instructions
enum Zba_ops = {SH1ADD, SH2ADD, SH3ADD}

union Zba_ast = {
  SH1ADD : (regbits, regbits, regbits),
  SH2ADD : (regbits, regbits, regbits),
  SH3ADD : (regbits, regbits, regbits)
}

// Zbb extension - Basic Bit Manipulation
enum Zbb_ops = {ANDN, ORN, XNOR, CLZ, CTZ, CPOP}

union Zbb_ast = {
  ANDN : (regbits, regbits, regbits),
  ORN  : (regbits, regbits, regbits),
  XNOR : (regbits, regbits, regbits),
  CLZ  : (regbits, regbits),
  CTZ  : (regbits, regbits),
  CPOP : (regbits, regbits)
}

// Zknd extension - NIST Suite: AES Decryption
enum Zknd_ops = {AES32DSI, AES32DSMI, AES64DS, AES64DSM}

union Zknd_ast = {
  AES32DSI  : (regbits, regbits, regbits),
  AES32DSMI : (regbits, regbits, regbits),
  AES64DS   : (regbits, regbits),
  AES64DSM  : (regbits, regbits)
}

// ============================================================================
// STANDARD RISC-V INSTRUCTIONS (should not be marked as UDB extensions)
// ============================================================================

register PC : bits(64)
register nextPC : bits(64)
register Xs : vector(32, dec, bits(64))

enum standard_iop = {RISCV_ADDI, RISCV_SLTI, RISCV_SLTIU}
enum standard_rop = {RISCV_ADD, RISCV_SUB, RISCV_SLL}

union standard_ast = {
  ITYPE : (bits(12), regbits, regbits),
  RTYPE : (regbits, regbits, regbits)
}

bitfield standard_instruction : bits(32) = {
  opcode : 6..0,
  rd     : 11..7,
  funct3 : 14..12,
  rs1    : 19..15,
  rs2    : 24..20,
  imm    : 31..20
}

// ============================================================================
// EXPLICIT UDB MARKERS (should be detected as UDB extensions)
// ============================================================================

register UDB_custom_extension_reg : bits(32)

enum UDB_custom_ops = {CUSTOM_OP1, CUSTOM_OP2, CUSTOM_OP3}

union UDB_custom_ast = {
  CUSTOM_OP1 : (regbits, regbits),
  CUSTOM_OP2 : (regbits, regbits, regbits),
  CUSTOM_OP3 : bits(20)
}

// ============================================================================
// FUNCTION DEFINITIONS
// ============================================================================

// UDB extension function
function execute_Zicsr(inst : Zicsr_ast) -> unit = {
  match inst {
    CSRRW(csr, rs1, rd) => (),
    CSRRS(csr, rs1, rd) => (),
    CSRRC(csr, rs1, rd) => ()
  }
}

// Standard function
function execute_standard(inst : standard_ast) -> unit = {
  match inst {
    ITYPE(imm, rs1, rd) => (),
    RTYPE(rs2, rs1, rd) => ()
  }
}

// ============================================================================
// VALUE SPECIFICATIONS
// ============================================================================

val decode_Zicsr : bits(32) -> option(Zicsr_ast) effect pure
val decode_standard : bits(32) -> option(standard_ast) effect pure

// ============================================================================
// MAPPING DEFINITIONS
// ============================================================================

mapping Zicsr_encoding = {
  CSRRW(csr, rs1, rd) <-> csr @ rs1 @ 0b001 @ rd @ 0b1110011
}

mapping standard_encoding = {
  ITYPE(imm, rs1, rd) <-> imm @ rs1 @ 0b000 @ rd @ 0b0010011
}
