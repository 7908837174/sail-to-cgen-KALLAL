#!/usr/bin/env python3
"""
Test script for UDB extension identification (Issue #307)
Tests the enhanced CGEN backend that identifies UDB-defined extensions
in the schema instead of hardcoding names in Ruby code.
"""

import os
import subprocess
import sys
import re

def run_command(cmd, cwd=None):
    """Run a command and return (returncode, stdout, stderr)"""
    try:
        result = subprocess.run(cmd, shell=True, cwd=cwd, 
                              capture_output=True, text=True, timeout=30)
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "Command timed out"
    except Exception as e:
        return -1, "", str(e)

def test_udb_extension_detection():
    """Test the UDB extension detection functionality"""
    print("Testing UDB Extension Detection (Issue #307)")
    print("=" * 60)
    
    test_file = "test_udb_extensions.sail"
    output_file = test_file.replace('.sail', '.cpu')
    
    if not os.path.exists(test_file):
        print(f"❌ Test file {test_file} not found")
        return False
        
    # Clean up any existing output
    if os.path.exists(output_file):
        os.remove(output_file)
        
    print(f"\n🧪 Testing UDB extension detection with {test_file}")
    print("-" * 50)
    
    # Generate CGEN output
    cmd = f"sail -cgen {test_file}"
    returncode, stdout, stderr = run_command(cmd)
    
    if returncode != 0:
        print(f"❌ CGEN generation failed: {stderr}")
        return False
        
    if not os.path.exists(output_file):
        print(f"❌ Expected output file {output_file} not created")
        return False
        
    print(f"✅ Generated {output_file}")
    
    # Read and analyze the generated CGEN output
    with open(output_file, 'r') as f:
        content = f.read()
    
    print("\n📄 Analyzing generated CGEN for UDB extension markers...")
    
    # Test cases for UDB extension detection
    test_cases = [
        {
            "name": "Zicsr Extension Detection",
            "pattern": r"udb-defined.*extension-name=Zicsr",
            "description": "Should detect Zicsr as UDB extension"
        },
        {
            "name": "Zifencei Extension Detection", 
            "pattern": r"udb-defined.*extension-name=Zifencei",
            "description": "Should detect Zifencei as UDB extension"
        },
        {
            "name": "Zba Extension Detection",
            "pattern": r"udb-defined.*extension-name=Zba",
            "description": "Should detect Zba as UDB extension"
        },
        {
            "name": "Zbb Extension Detection",
            "pattern": r"udb-defined.*extension-name=Zbb", 
            "description": "Should detect Zbb as UDB extension"
        },
        {
            "name": "Zknd Extension Detection",
            "pattern": r"udb-defined.*extension-name=Zknd",
            "description": "Should detect Zknd as UDB extension"
        },
        {
            "name": "Explicit UDB Marker Detection",
            "pattern": r"udb-defined.*extension-category=UDB-defined",
            "description": "Should detect explicit UDB_ prefixed extensions"
        },
        {
            "name": "Standard Instructions Not Marked",
            "pattern": r"standard.*udb-defined",
            "description": "Standard instructions should NOT be marked as UDB extensions",
            "should_not_match": True
        }
    ]
    
    results = []
    for test_case in test_cases:
        pattern = test_case["pattern"]
        should_not_match = test_case.get("should_not_match", False)
        
        matches = re.findall(pattern, content, re.IGNORECASE)
        
        if should_not_match:
            if not matches:
                print(f"✅ {test_case['name']}: {test_case['description']}")
                results.append(True)
            else:
                print(f"❌ {test_case['name']}: Found unexpected matches: {matches}")
                results.append(False)
        else:
            if matches:
                print(f"✅ {test_case['name']}: {test_case['description']}")
                results.append(True)
            else:
                print(f"❌ {test_case['name']}: {test_case['description']} - No matches found")
                results.append(False)
    
    # Show sample output
    print(f"\n📋 Sample CGEN output with UDB extension metadata:")
    lines = content.split('\n')
    udb_lines = [line for line in lines if 'udb-defined' in line.lower()]
    
    if udb_lines:
        for line in udb_lines[:5]:  # Show first 5 UDB extension lines
            print(f"   {line.strip()}")
        if len(udb_lines) > 5:
            print(f"   ... and {len(udb_lines) - 5} more UDB extension definitions")
    else:
        print("   No UDB extension metadata found in output")
    
    # Summary
    passed = sum(results)
    total = len(results)
    
    print(f"\n📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All UDB extension detection tests passed!")
        return True
    else:
        print("❌ Some UDB extension detection tests failed")
        return False

def check_schema_extensibility():
    """Check that the schema-based approach is extensible"""
    print("\n🔧 Checking Schema Extensibility")
    print("-" * 40)
    
    # Check if the extension detection logic is configurable
    cgen_backend_file = "src/cgen_backend.ml"
    
    if not os.path.exists(cgen_backend_file):
        print(f"❌ CGEN backend file {cgen_backend_file} not found")
        return False
    
    with open(cgen_backend_file, 'r') as f:
        content = f.read()
    
    extensibility_checks = [
        {
            "name": "Extension Metadata Type",
            "pattern": r"type extension_metadata",
            "description": "Extension metadata type defined"
        },
        {
            "name": "UDB Detection Function",
            "pattern": r"detect_udb_extension",
            "description": "UDB extension detection function exists"
        },
        {
            "name": "Configurable Extension Patterns",
            "pattern": r"udb_patterns.*=",
            "description": "Extension patterns are configurable"
        },
        {
            "name": "Schema-based Identification",
            "pattern": r"extension-name=|extension-category=",
            "description": "Schema includes extension identification attributes"
        }
    ]
    
    results = []
    for check in extensibility_checks:
        if re.search(check["pattern"], content, re.IGNORECASE):
            print(f"✅ {check['name']}: {check['description']}")
            results.append(True)
        else:
            print(f"❌ {check['name']}: {check['description']} - Not found")
            results.append(False)
    
    passed = sum(results)
    total = len(results)
    
    print(f"\n📊 Extensibility Check: {passed}/{total} checks passed")
    
    return passed == total

def main():
    """Main test function"""
    print("UDB Extension Schema Enhancement Test Suite")
    print("Testing Issue #307: Identify UDB extensions in schema")
    print("=" * 70)
    
    # Check if we're in the right directory
    if not os.path.exists("src/sail.ml"):
        print("❌ Please run this script from the sail-to-cgen root directory")
        sys.exit(1)
    
    # Run tests
    detection_passed = test_udb_extension_detection()
    extensibility_passed = check_schema_extensibility()
    
    print("\n" + "=" * 70)
    print("Test Summary:")
    print(f"- UDB Extension Detection: {'✅ PASSED' if detection_passed else '❌ FAILED'}")
    print(f"- Schema Extensibility: {'✅ PASSED' if extensibility_passed else '❌ FAILED'}")
    
    if detection_passed and extensibility_passed:
        print("\n🎉 Issue #307 Successfully Resolved!")
        print("✅ UDB extensions are now identified in schema instead of hardcoded Ruby")
        print("✅ System is extensible for new UDB extensions without code changes")
        print("✅ Extension metadata is properly embedded in CGEN output")
    else:
        print("\n❌ Issue #307 resolution incomplete")
        print("Some tests failed - please review the implementation")
    
    return detection_passed and extensibility_passed

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
