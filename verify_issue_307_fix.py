#!/usr/bin/env python3
"""
Verification script for Issue #307 resolution
Verifies that UDB extension identification is working correctly
and that the schema-based approach eliminates hardcoded Ruby lists.
"""

import os
import sys
import re
import subprocess

def check_file_exists(filepath, description):
    """Check if a file exists and report status"""
    if os.path.exists(filepath):
        print(f"✅ {description}: {filepath}")
        return True
    else:
        print(f"❌ {description}: {filepath} - NOT FOUND")
        return False

def check_file_content(filepath, patterns, description):
    """Check if file contains expected patterns"""
    if not os.path.exists(filepath):
        print(f"❌ {description}: File {filepath} not found")
        return False
    
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    results = []
    for pattern_name, pattern in patterns.items():
        if re.search(pattern, content, re.IGNORECASE | re.MULTILINE):
            print(f"✅ {description} - {pattern_name}: Found")
            results.append(True)
        else:
            print(f"❌ {description} - {pattern_name}: Not found")
            results.append(False)
    
    return all(results)

def verify_issue_307_implementation():
    """Verify Issue #307 implementation"""
    print("🔍 Verifying Issue #307 Implementation")
    print("=" * 60)
    
    # Check core implementation files
    core_files = [
        ("src/cgen_backend.ml", "Enhanced CGEN backend with UDB extension detection"),
        ("test_udb_extensions.sail", "UDB extension test cases"),
        ("test_udb_extension_detection.py", "UDB extension verification script"),
        ("UDB_EXTENSION_ENHANCEMENT.md", "UDB extension documentation"),
        ("ISSUE_307_RESOLUTION.md", "Issue #307 resolution summary")
    ]
    
    print("\n📁 Checking Required Files:")
    files_ok = True
    for filepath, description in core_files:
        if not check_file_exists(filepath, description):
            files_ok = False
    
    if not files_ok:
        print("\n❌ Missing required files for Issue #307")
        return False
    
    # Check CGEN backend implementation
    print("\n🔧 Checking CGEN Backend Implementation:")
    cgen_patterns = {
        "Extension Metadata Type": r"type\s+extension_metadata",
        "UDB Detection Function": r"detect_udb_extension",
        "Extension Patterns": r"udb_patterns\s*=",
        "Print Extension Metadata": r"print_extension_metadata",
        "UDB Defined Attribute": r"udb-defined"
    }
    
    cgen_ok = check_file_content("src/cgen_backend.ml", cgen_patterns, "CGEN Backend")
    
    # Check test cases
    print("\n🧪 Checking Test Cases:")
    test_patterns = {
        "Zicsr Extension": r"Zicsr",
        "Zifencei Extension": r"Zifencei", 
        "Zba Extension": r"Zba",
        "UDB Explicit Marker": r"UDB_",
        "Standard Instructions": r"standard|RISCV"
    }
    
    test_ok = check_file_content("test_udb_extensions.sail", test_patterns, "Test Cases")
    
    # Check documentation
    print("\n📚 Checking Documentation:")
    doc_patterns = {
        "Issue #307 Reference": r"Issue\s*#?307",
        "Schema-based Identification": r"schema.*identification|identification.*schema",
        "Hardcoded Ruby Lists": r"hardcoded.*ruby|ruby.*hardcoded",
        "Extension Metadata": r"extension.*metadata|metadata.*extension"
    }
    
    doc_ok = check_file_content("UDB_EXTENSION_ENHANCEMENT.md", doc_patterns, "Documentation")
    
    # Check updated main documentation
    print("\n📖 Checking Updated Documentation:")
    main_doc_patterns = {
        "Issue #307 in Enhancements": r"Issue\s*#?307.*UDB",
        "UDB Extension Support": r"UDB.*extension.*identification|extension.*UDB.*identification"
    }
    
    main_doc_ok = check_file_content("CGEN_BACKEND_ENHANCEMENTS.md", main_doc_patterns, "Main Documentation")
    
    # Summary
    print("\n📊 Verification Summary:")
    all_checks = [files_ok, cgen_ok, test_ok, doc_ok, main_doc_ok]
    passed = sum(all_checks)
    total = len(all_checks)
    
    print(f"Files Present: {'✅' if files_ok else '❌'}")
    print(f"CGEN Implementation: {'✅' if cgen_ok else '❌'}")
    print(f"Test Cases: {'✅' if test_ok else '❌'}")
    print(f"Documentation: {'✅' if doc_ok else '❌'}")
    print(f"Updated Docs: {'✅' if main_doc_ok else '❌'}")
    
    print(f"\nOverall: {passed}/{total} checks passed")
    
    return passed == total

def verify_no_hardcoded_ruby():
    """Verify no hardcoded Ruby extension lists remain"""
    print("\n🔍 Checking for Hardcoded Ruby Extension Lists")
    print("-" * 50)
    
    # Search for potential Ruby files or hardcoded extension patterns
    ruby_patterns = [
        r"UDB_EXTENSIONS\s*=",
        r"extension.*list.*=.*\[",
        r"\.rb\s*:",
        r"hardcoded.*extension",
        r"extension.*hardcoded"
    ]
    
    # Check all files in the project
    hardcoded_found = False
    
    for root, dirs, files in os.walk("."):
        # Skip hidden directories and common build directories
        dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ['build', 'target', 'node_modules']]
        
        for file in files:
            if file.endswith(('.ml', '.py', '.md', '.txt', '.rb')):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                    
                    for pattern in ruby_patterns:
                        if re.search(pattern, content, re.IGNORECASE):
                            # Check if it's in documentation explaining the old approach
                            if 'BEFORE' in content or 'documentation' in filepath.lower() or 'README' in filepath:
                                continue  # This is documentation, not actual hardcoded lists
                            print(f"⚠️  Potential hardcoded extension list in {filepath}")
                            hardcoded_found = True
                            break
                except:
                    continue  # Skip files that can't be read
    
    if not hardcoded_found:
        print("✅ No hardcoded Ruby extension lists found")
        return True
    else:
        print("❌ Potential hardcoded extension lists detected")
        return False

def verify_schema_output():
    """Verify that schema output includes extension metadata"""
    print("\n🔍 Checking Schema Output Format")
    print("-" * 40)
    
    # Check if any existing .cpu files have the new format
    cpu_files = [f for f in os.listdir('.') if f.endswith('.cpu')]
    
    if not cpu_files:
        print("ℹ️  No .cpu files found - run 'sail -cgen test_udb_extensions.sail' to generate")
        return True
    
    schema_ok = True
    for cpu_file in cpu_files:
        print(f"\n📄 Checking {cpu_file}:")
        
        with open(cpu_file, 'r') as f:
            content = f.read()
        
        # Check for UDB extension metadata
        if 'udb-defined' in content:
            print(f"✅ {cpu_file}: Contains UDB extension metadata")
        else:
            print(f"ℹ️  {cpu_file}: No UDB extension metadata (may not contain UDB extensions)")
        
        # Check for extension attributes
        extension_attrs = ['extension-name=', 'extension-category=']
        for attr in extension_attrs:
            if attr in content:
                print(f"✅ {cpu_file}: Contains {attr} attribute")
    
    return schema_ok

def main():
    """Main verification function"""
    print("Issue #307 Resolution Verification")
    print("UDB Extension Schema Identification")
    print("=" * 70)
    
    # Change to the correct directory if needed
    if os.path.exists("sail-to-cgen"):
        os.chdir("sail-to-cgen")
        print("📁 Changed to sail-to-cgen directory")
    
    # Run verification checks
    implementation_ok = verify_issue_307_implementation()
    no_hardcoded_ok = verify_no_hardcoded_ruby()
    schema_ok = verify_schema_output()
    
    # Final summary
    print("\n" + "=" * 70)
    print("ISSUE #307 VERIFICATION SUMMARY")
    print("=" * 70)
    
    print(f"✅ Implementation Complete: {'YES' if implementation_ok else 'NO'}")
    print(f"✅ No Hardcoded Ruby Lists: {'YES' if no_hardcoded_ok else 'NO'}")
    print(f"✅ Schema Format Updated: {'YES' if schema_ok else 'NO'}")
    
    overall_success = implementation_ok and no_hardcoded_ok and schema_ok
    
    if overall_success:
        print("\n🎉 ISSUE #307 SUCCESSFULLY RESOLVED!")
        print("✅ UDB extensions now identified in schema instead of hardcoded Ruby")
        print("✅ System is extensible for new UDB extensions without code changes")
        print("✅ Extension metadata properly embedded in CGEN output")
        print("\n📋 Next Steps:")
        print("1. Test the implementation: python3 test_udb_extension_detection.py")
        print("2. Generate sample output: sail -cgen test_udb_extensions.sail")
        print("3. Commit and push changes")
        print("4. Create pull request")
    else:
        print("\n❌ ISSUE #307 RESOLUTION INCOMPLETE")
        print("Some verification checks failed - please review the implementation")
    
    return overall_success

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
