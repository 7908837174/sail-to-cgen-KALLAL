default Order dec

$include <prelude.sail>

// Test case for CGEN backend register processing issue
// This file defines various types of registers that should be 
// processed by the CGEN backend but are currently ignored

// Simple scalar registers
register PC : bits(64)
register SP : bits(64) 
register LR : bits(32)

// Vector register (register file)
register GPR : vector(32, dec, bits(64))

// Register with initialization
register CSR_STATUS : bits(32) = 0x00000000

// Different bit widths
register FLAG_REG : bits(8)
register WIDE_REG : bits(128)

function main() -> unit = {
    // These register operations should generate corresponding
    // CGEN hardware definitions, but currently don't
    PC = 0x1000;
    SP = 0x7fff0000;
    LR = 0x12345678;
    GPR[1] = 0x42;
    CSR_STATUS = 0x80000000;
    FLAG_REG = 0xff;
    WIDE_REG = 0x123456789abcdef0123456789abcdef0
}
