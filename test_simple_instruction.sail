default Order dec

$include <prelude.sail>

// Simple test case for instruction processing
register PC : bits(64)
register GPR : vector(32, dec, bits(64))

// Simple instruction type
typedef regbits = bits(5)
typedef imm12 = bits(12)

// Instruction AST
union ast = ADDI : (regbits, regbits, imm12)

// Instruction execution
function execute(ADDI(rd, rs1, imm)) = {
    GPR[rd] = GPR[rs1] + sign_extend(imm);
    PC = PC + 4
}

// Helper function
val sign_extend : forall 'n 'm, 'n <= 'm. bits('n) -> bits('m)
function sign_extend(x) = sail_sign_extend(x, sizeof('m))

function main() -> unit = {
    let instr = ADDI(0b00001, 0b00000, 0x123);
    execute(instr)
}
