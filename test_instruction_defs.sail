default Order dec

$include <prelude.sail>

// Type definitions for instruction set
union ast = {
  ADDI : (bits(12), regbits, regbits),
  SLTI : (bits(12), regbits, regbits),
  LUI  : (bits(20), regbits)
}

enum iop = {RISCV_ADDI, RISCV_SLTI, RISCV_SLTIU}

enum uop = {RISCV_LUI, RISCV_AUIPC}

bitfield instruction : bits(32) = {
  opcode : 6..0,
  rd     : 11..7,
  funct3 : 14..12,
  rs1    : 19..15,
  imm_i  : 31..20,
  imm_u  : 31..12
}

// Register definitions
register PC : bits(64)
register nextPC : bits(64)
register Xs : vector(32, dec, bits(64))

// Function specifications
val decode : bits(32) -> option(ast) effect pure
val execute : ast -> unit effect {rmem, rreg, wreg}

// Scattered function definitions
scattered function decode

function clause decode(bv) = {
  let opcode = bv[6..0];
  match opcode {
    0b0010011 => decode_itype(bv),
    0b0110111 => decode_utype(bv),
    _         => None()
  }
}

function decode_itype(bv : bits(32)) -> option(ast) = {
  let imm = bv[31..20];
  let rs1 = bv[19..15];
  let funct3 = bv[14..12];
  let rd = bv[11..7];
  match funct3 {
    0b000 => Some(ADDI(imm, rs1, rd)),
    0b010 => Some(SLTI(imm, rs1, rd)),
    _     => None()
  }
}

function decode_utype(bv : bits(32)) -> option(ast) = {
  let imm = bv[31..12];
  let rd = bv[11..7];
  Some(LUI(imm, rd))
}

scattered function execute

function clause execute(ADDI(imm, rs1, rd)) = {
  Xs[rd] = Xs[rs1] + EXTS(imm)
}

function clause execute(SLTI(imm, rs1, rd)) = {
  Xs[rd] = if (Xs[rs1] <_s EXTS(imm)) then 0x1 else 0x0
}

function clause execute(LUI(imm, rd)) = {
  Xs[rd] = EXTZ(imm) << 12
}

// Mapping definition
mapping clause encdec = ADDI(imm, rs1, rd) <-> imm @ rs1 @ 0b000 @ rd @ 0b0010011

end decode
end execute
