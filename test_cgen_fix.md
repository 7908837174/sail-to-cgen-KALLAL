# Test Case for CGEN Backend Fix

## Input Sail File (test_cgen_issue.sail)

```sail
default Order dec

$include <prelude.sail>

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
    PC = 0x1000;
    SP = 0x7fff0000;
    LR = 0x12345678;
    GPR[1] = 0x42;
    CSR_STATUS = 0x80000000;
    FLAG_REG = 0xff;
    WIDE_REG = 0x123456789abcdef0123456789abcdef0
}
```

## Expected CGEN Output (test_cgen_issue.cpu)

```cgen
;; CGEN CPU description generated from Sail specification
;; This file contains hardware register definitions

(define-hardware
  (name h-PC)
  (comment "PC")
  (attrs all-isas all-machs)
  (type register DI)
)

(define-hardware
  (name h-SP)
  (comment "SP")
  (attrs all-isas all-machs)
  (type register DI)
)

(define-hardware
  (name h-LR)
  (comment "LR")
  (attrs all-isas all-machs)
  (type register SI)
)

(define-hardware
  (name h-GPR)
  (comment "GPR")
  (attrs all-isas all-machs)
  (type register DI)
)

(define-hardware
  (name h-CSR_STATUS)
  (comment "CSR_STATUS")
  (attrs all-isas all-machs)
  (type register SI)
)

(define-hardware
  (name h-FLAG_REG)
  (comment "FLAG_REG")
  (attrs all-isas all-machs)
  (type register QI)
)

(define-hardware
  (name h-WIDE_REG)
  (comment "WIDE_REG")
  (attrs all-isas all-machs)
  (type register TI)
)

;; End of generated CGEN file
```

## Command to Test

```bash
# Using the fixed CGEN backend
sail -cgen -cgen_output test_output.cpu test_cgen_issue.sail

# Or with default output naming
sail -cgen -o test_output test_cgen_issue.sail
# This would create test_output.cpu
```

## Key Improvements Made

1. **Proper AST Processing**: Now processes the actual Sail AST instead of outputting hardcoded data
2. **Register Type Mapping**: Maps Sail types (bits(n)) to appropriate CGEN types (QI, HI, SI, DI, TI)
3. **Configurable Output**: Supports custom output file paths via -cgen_output option
4. **Proper CGEN Format**: Generates valid CGEN define-hardware entries
5. **Error Handling**: Better error handling with proper exception propagation
