default Order dec

$include <prelude.sail>

// Simple register definitions
register PC : bits(64)
register configuration MISA : bits(64) = 0x8000000000141101

// Simple enum type
enum simple_op = {OP_ADD, OP_SUB, OP_MUL}

// Simple union type for instructions
union simple_ast = {
  ADD : (regbits, regbits, regbits),
  SUB : (regbits, regbits, regbits)
}

// Simple bitfield
bitfield simple_instruction : bits(32) = {
  opcode : 6..0,
  rd     : 11..7,
  rs1    : 19..15,
  rs2    : 24..20
}

// Simple mapping
mapping simple_mapping = {
  ADD(rd, rs1, rs2) <-> rs2 @ rs1 @ 0b000 @ rd @ 0b0110011
}

// Simple function
function simple_execute(inst : simple_ast) -> unit = {
  match inst {
    ADD(rd, rs1, rs2) => (),
    SUB(rd, rs1, rs2) => ()
  }
}
