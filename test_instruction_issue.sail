default Order dec

$include <prelude.sail>

// Test case for CGEN backend instruction processing issue
// This file defines instruction types and semantics that should be 
// processed by the CGEN backend but are currently ignored

// Register definitions (these work with the previous fix)
register PC : bits(64)
register GPR : vector(32, dec, bits(64))
register FLAGS : bits(32)

// Type definitions for instruction operands
typedef regbits = bits(5)
typedef imm12 = bits(12)
typedef imm20 = bits(20)

// Instruction AST definition - this should generate CGEN instruction definitions
scattered typedef ast = const union

// Simple instruction types that should generate CGEN define-insn entries
union ast member (regbits, regbits, imm12) ADDI
union ast member (regbits, regbits, regbits) ADD  
union ast member (regbits, imm20) LUI
union ast member (regbits, regbits, imm12) LOAD
union ast member (regbits, regbits, imm12) STORE

// Instruction execution semantics
scattered function unit execute

function clause execute (ADDI(rd, rs1, imm)) = {
    GPR[rd] = GPR[rs1] + sign_extend(imm);
    PC = PC + 4
}

function clause execute (ADD(rd, rs1, rs2)) = {
    GPR[rd] = GPR[rs1] + GPR[rs2];
    PC = PC + 4
}

function clause execute (LUI(rd, imm)) = {
    GPR[rd] = sign_extend(imm) << 12;
    PC = PC + 4
}

function clause execute (LOAD(rd, rs1, offset)) = {
    let addr = GPR[rs1] + sign_extend(offset);
    GPR[rd] = read_mem(addr, 8);
    PC = PC + 4
}

function clause execute (STORE(rs2, rs1, offset)) = {
    let addr = GPR[rs1] + sign_extend(offset);
    write_mem(addr, 8, GPR[rs2]);
    PC = PC + 4
}

// Instruction decode mappings (these should also be processed)
mapping clause encdec = ADDI(rd, rs1, imm) <-> imm : bits(12) @ rs1 : regbits @ 0b000 : bits(3) @ rd : regbits @ 0b0010011 : bits(7)
mapping clause encdec = ADD(rd, rs1, rs2)  <-> 0b0000000 : bits(7) @ rs2 : regbits @ rs1 : regbits @ 0b000 : bits(3) @ rd : regbits @ 0b0110011 : bits(7)
mapping clause encdec = LUI(rd, imm)       <-> imm : bits(20) @ rd : regbits @ 0b0110111 : bits(7)

// Helper functions
val read_mem : (bits(64), nat) -> bits(64) effect {rmem}
function read_mem(addr, size) = 0x0000000000000000

val write_mem : (bits(64), nat, bits(64)) -> unit effect {wmem}
function write_mem(addr, size, data) = ()

val sign_extend : forall 'n 'm, 'n <= 'm. bits('n) -> bits('m)
function sign_extend(x) = sail_sign_extend(x, sizeof('m))

function main() -> unit = {
    // Test instruction execution
    let instr1 = ADDI(0b00001, 0b00000, 0x123);
    let instr2 = ADD(0b00010, 0b00001, 0b00000);
    let instr3 = LUI(0b00011, 0x12345);
    
    execute(instr1);
    execute(instr2);
    execute(instr3)
}
