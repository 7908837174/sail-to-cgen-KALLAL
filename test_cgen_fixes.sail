default Order dec

$include <prelude.sail>

register PC : bits(64)
register SP : bits(64)
register configuration MISA : bits(64) = 0x8000000000141101

val m : unit <-> int(1)

mapping m = {
  () <-> 1
}

function main(() : unit) -> unit = {
    PC = 0x1000;
    print_bits("PC = ", PC)
}
