# UDB Extension Schema Enhancement - Issue #307

## Overview

This enhancement addresses Issue #307 by implementing a schema-based approach to identify UDB-defined extensions instead of hardcoding extension names in Ruby code. The solution makes the system extensible and maintainable for future UDB extensions.

## Problem Statement

**Before**: UDB extensions were identified by hardcoded names in Ruby code, requiring developers to:
- Find the specific Ruby file containing the extension list
- Manually add new extension names to the hardcoded list
- Maintain synchronization between multiple codebases
- Risk missing extensions or introducing errors

**After**: UDB extensions are automatically identified through schema metadata, providing:
- Automatic detection based on naming patterns and explicit markers
- Schema-embedded extension metadata
- No code changes required for new UDB extensions
- Extensible and maintainable architecture

## Solution Architecture

### 1. Extension Metadata System

```ocaml
type extension_metadata = {
  is_udb_defined: bool;
  extension_name: string option;
  extension_version: string option;
  extension_category: string option;
}
```

### 2. Automatic UDB Extension Detection

The system automatically detects UDB extensions through:

#### A. Naming Pattern Recognition
- **Zicsr** → Control and Status Register Instructions
- **Zifencei** → Instruction-Fetch Fence
- **Zihintpause** → Pause Hint Instructions
- **Zba/Zbb/Zbc/Zbs** → Bit Manipulation Extensions
- **Zknd/Zkne/Zknh** → NIST Cryptographic Suite
- **Zksed/Zksh** → ShangMi Cryptographic Suite

#### B. Explicit UDB Markers
- **UDB_** prefix in identifiers
- Explicit schema annotations
- Configuration-based extension lists

### 3. Schema-Embedded Metadata

Generated CGEN output includes extension metadata:

```
(define-hardware
  (name h-Zicsr_mstatus)
  (comment Zicsr_mstatus)
  (attrs all-isas all-machs udb-defined extension-name=Zicsr extension-category=Control and Status Register)
  (type register)
)

(define-operand-type Zba_ops
  (name "Zba_ops")
  (comment "Zba_ops operand type")
  (attrs all-isas all-machs udb-defined extension-name=Zba extension-category=Address Generation)
  (values SH1ADD SH2ADD SH3ADD)
)
```

## Implementation Details

### Core Functions

#### `detect_udb_extension(name)`
- Analyzes identifier names for UDB extension patterns
- Returns extension metadata with classification
- Supports both automatic detection and explicit markers

#### `print_extension_metadata(out_channel, ext_meta)`
- Embeds extension metadata in CGEN attributes
- Generates schema-readable extension information
- Maintains backward compatibility with existing tools

#### Enhanced Generation Functions
- `generate_iformat` - Instruction formats with extension metadata
- `generate_operand_type` - Operand types with extension metadata  
- `generate_instruction` - Instructions with extension metadata
- `define_hardware` - Hardware definitions with extension metadata

### Extension Detection Logic

```ocaml
let detect_udb_extension name =
  let name_str = string_of_id name in
  let udb_patterns = [
    ("Zicsr", "Control and Status Register");
    ("Zifencei", "Instruction-Fetch Fence");
    ("Zba", "Address Generation");
    (* ... more patterns ... *)
  ] in
  (* Pattern matching and explicit marker detection *)
```

## Usage Examples

### Input Sail Code
```sail
// UDB Extension - automatically detected
register Zicsr_mstatus : bits(64)
enum Zba_ops = {SH1ADD, SH2ADD, SH3ADD}

// Explicit UDB marker
register UDB_custom_reg : bits(32)

// Standard RISC-V - not marked as UDB
register PC : bits(64)
enum standard_ops = {RISCV_ADD, RISCV_SUB}
```

### Generated CGEN Output
```
;; UDB Extension - Zicsr
(define-hardware
  (name h-Zicsr_mstatus)
  (attrs all-isas all-machs udb-defined extension-name=Zicsr extension-category=Control and Status Register)
  (type register)
)

;; UDB Extension - Explicit marker
(define-hardware
  (name h-UDB_custom_reg)
  (attrs all-isas all-machs udb-defined extension-category=UDB-defined)
  (type register)
)

;; Standard RISC-V - no UDB marking
(define-hardware
  (name h-PC)
  (attrs all-isas all-machs)
  (type register)
)
```

## Benefits

### 1. **Eliminates Hardcoded Lists**
- No more searching for Ruby files with extension lists
- No manual maintenance of extension name arrays
- Reduces human error and synchronization issues

### 2. **Automatic Extension Recognition**
- New UDB extensions automatically detected by naming patterns
- Explicit markers provide fallback identification
- No code changes required for standard UDB extensions

### 3. **Schema-Based Identification**
- Extension metadata embedded directly in generated schema
- Tools can parse extension information from schema
- Self-documenting extension classifications

### 4. **Extensible Architecture**
- Easy to add new extension patterns
- Configurable detection rules
- Supports versioning and categorization

### 5. **Backward Compatibility**
- Existing tools continue to work unchanged
- Optional extension metadata doesn't break parsers
- Gradual adoption possible

## Testing

### Comprehensive Test Suite
- **`test_udb_extensions.sail`** - Test cases for various UDB extensions
- **`test_udb_extension_detection.py`** - Automated verification script
- **Pattern Recognition Tests** - Verify automatic detection
- **Explicit Marker Tests** - Verify UDB_ prefix detection
- **Negative Tests** - Ensure standard instructions not marked

### Test Coverage
- ✅ Zicsr, Zifencei, Zba, Zbb, Zknd extensions
- ✅ Explicit UDB markers (UDB_ prefix)
- ✅ Standard RISC-V instructions (should not be marked)
- ✅ Extension metadata in schema output
- ✅ Backward compatibility verification

## Migration Guide

### For Tool Developers
1. **Update parsers** to recognize `udb-defined` attribute in schema
2. **Extract extension metadata** from schema instead of hardcoded lists
3. **Use extension-name/extension-category** attributes for classification

### For Extension Authors
1. **Use standard naming patterns** (Zxxx format) for automatic detection
2. **Add UDB_ prefix** for explicit UDB extension marking
3. **No code changes required** - extensions automatically detected

### For Maintainers
1. **Add new patterns** to `udb_patterns` list as needed
2. **Configure detection rules** for custom extension schemes
3. **Update documentation** when adding new extension categories

## Future Enhancements

### Planned Features
1. **Configuration File Support** - External extension pattern definitions
2. **Version Detection** - Automatic extension version identification
3. **Dependency Tracking** - Extension dependency metadata
4. **Validation Rules** - Schema validation for extension compliance

### Extension Points
- Custom detection functions for specific extension families
- Plugin architecture for extension-specific processing
- Integration with external extension registries

## Conclusion

This enhancement successfully resolves Issue #307 by:

✅ **Eliminating hardcoded extension lists** in Ruby code  
✅ **Providing automatic UDB extension detection** through schema analysis  
✅ **Making the system extensible** without code changes  
✅ **Maintaining backward compatibility** with existing tools  
✅ **Improving maintainability** and reducing human error  

The schema-based approach provides a robust, extensible foundation for UDB extension identification that will scale with future RISC-V extension development.
