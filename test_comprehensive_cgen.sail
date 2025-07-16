default Order dec

$include <prelude.sail>

/* Comprehensive test case for enhanced CGEN backend
   Tests all supported definition types:
   - Registers (regular and configuration)
   - Type definitions (enums, unions, bitfields, records)
   - Function definitions
   - Scattered definitions
   - Mapping definitions
   - Value specifications
*/

// ============================================================================
// REGISTER DEFINITIONS
// ============================================================================

register PC : bits(64)
register nextPC : bits(64)
register configuration MISA : bits(64) = 0x8000000000141101
register Xs : vector(32, dec, bits(64))

// ============================================================================
// TYPE DEFINITIONS
// ============================================================================

// Enum types for operand types
enum iop = {RISCV_ADDI, RISCV_SLTI, RISCV_SLTIU, RISCV_XORI, RISCV_ORI, RISCV_ANDI}
enum rop = {RISCV_ADD, RISCV_SUB, RISCV_SLL, RISCV_SLT, RISCV_SLTU}
enum uop = {RISCV_LUI, RISCV_AUIPC}
enum bop = {RISCV_BEQ, RISCV_BNE, RISCV_BLT, RISCV_BGE, RISCV_BLTU, RISCV_BGEU}

// Union type for instruction AST
union ast = {
  ITYPE : (bits(12), regbits, regbits, iop),
  RTYPE : (regbits, regbits, regbits, rop),
  UTYPE : (bits(20), regbits, uop),
  BTYPE : (bits(13), regbits, regbits, bop),
  LOAD  : (bits(12), regbits, regbits),
  STORE : (bits(12), regbits, regbits)
}

// Bitfield types for instruction formats
bitfield instruction : bits(32) = {
  opcode : 6..0,
  rd     : 11..7,
  funct3 : 14..12,
  rs1    : 19..15,
  rs2    : 24..20,
  imm_i  : 31..20,
  imm_u  : 31..12,
  imm_b  : 31..25 @ 11..7,
  imm_s  : 31..25 @ 11..7
}

// Record type for processor state
struct processor_state = {
  pc : bits(64),
  registers : vector(32, dec, bits(64)),
  memory : vector(1024, dec, bits(8))
}

// Type abbreviations
type regbits = bits(5)
type xlen_t = bits(64)

// ============================================================================
// VALUE SPECIFICATIONS
// ============================================================================

val decode : bits(32) -> option(ast) effect pure
val execute : ast -> unit effect {rmem, rreg, wreg}
val EXTS : forall 'n 'm. (bits('n)) -> bits('m) effect pure
val EXTZ : forall 'n 'm. (bits('n)) -> bits('m) effect pure

// ============================================================================
// SCATTERED FUNCTION DEFINITIONS
// ============================================================================

scattered function decode

function clause decode(bv) = {
  let opcode = bv[6..0];
  match opcode {
    0b0010011 => decode_itype(bv),
    0b0110011 => decode_rtype(bv),
    0b0110111 => decode_utype(bv),
    0b1100011 => decode_btype(bv),
    0b0000011 => decode_load(bv),
    0b0100011 => decode_store(bv),
    _         => None()
  }
}

scattered function execute

function clause execute(ITYPE(imm, rs1, rd, op)) = {
  match op {
    RISCV_ADDI => Xs[rd] = Xs[rs1] + EXTS(imm),
    RISCV_SLTI => Xs[rd] = if (Xs[rs1] <_s EXTS(imm)) then 0x1 else 0x0,
    _          => ()
  }
}

function clause execute(RTYPE(rs2, rs1, rd, op)) = {
  match op {
    RISCV_ADD => Xs[rd] = Xs[rs1] + Xs[rs2],
    RISCV_SUB => Xs[rd] = Xs[rs1] - Xs[rs2],
    _         => ()
  }
}

function clause execute(UTYPE(imm, rd, op)) = {
  match op {
    RISCV_LUI   => Xs[rd] = EXTZ(imm) << 12,
    RISCV_AUIPC => Xs[rd] = PC + (EXTZ(imm) << 12),
    _           => ()
  }
}

// ============================================================================
// MAPPING DEFINITIONS
// ============================================================================

mapping clause encdec = ITYPE(imm, rs1, rd, RISCV_ADDI) <-> imm @ rs1 @ 0b000 @ rd @ 0b0010011
mapping clause encdec = RTYPE(rs2, rs1, rd, RISCV_ADD)  <-> 0b0000000 @ rs2 @ rs1 @ 0b000 @ rd @ 0b0110011
mapping clause encdec = UTYPE(imm, rd, RISCV_LUI)       <-> imm @ rd @ 0b0110111

// ============================================================================
// REGULAR FUNCTION DEFINITIONS
// ============================================================================

function decode_itype(bv : bits(32)) -> option(ast) = {
  let imm = bv[31..20];
  let rs1 = bv[19..15];
  let funct3 = bv[14..12];
  let rd = bv[11..7];
  match funct3 {
    0b000 => Some(ITYPE(imm, rs1, rd, RISCV_ADDI)),
    0b010 => Some(ITYPE(imm, rs1, rd, RISCV_SLTI)),
    _     => None()
  }
}

function decode_rtype(bv : bits(32)) -> option(ast) = {
  let funct7 = bv[31..25];
  let rs2 = bv[24..20];
  let rs1 = bv[19..15];
  let funct3 = bv[14..12];
  let rd = bv[11..7];
  match (funct7, funct3) {
    (0b0000000, 0b000) => Some(RTYPE(rs2, rs1, rd, RISCV_ADD)),
    (0b0100000, 0b000) => Some(RTYPE(rs2, rs1, rd, RISCV_SUB)),
    _                  => None()
  }
}

function decode_utype(bv : bits(32)) -> option(ast) = {
  let imm = bv[31..12];
  let rd = bv[11..7];
  Some(UTYPE(imm, rd, RISCV_LUI))
}

// ============================================================================
// VALUE DEFINITIONS
// ============================================================================

let zero_register : regbits = 0b00000
let ra_register : regbits = 0b00001

// ============================================================================
// END SCATTERED DEFINITIONS
// ============================================================================

end decode
end execute
