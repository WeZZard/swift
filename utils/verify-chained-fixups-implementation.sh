#!/bin/bash

# Script to verify DYLD chained fixups implementation in swift-reflection-dump
# Usage: ./verify-chained-fixups-implementation.sh [build-dir]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWIFT_SOURCE_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${1:-$SWIFT_SOURCE_ROOT/../build/Ninja-DebugAssert/swift-macosx-$(uname -m)}"
TEMP_DIR=$(mktemp -d)

# Test counters
PASSED=0
FAILED=0
SKIPPED=0

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

run_test() {
    local test_name=$1
    local test_cmd=$2
    
    echo -n "Testing $test_name... "
    if eval "$test_cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC}"
        ((FAILED++))
        return 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if [[ ! -d "$BUILD_DIR" ]]; then
        log_error "Build directory not found: $BUILD_DIR"
        log_info "Please build Swift first with: utils/build-script"
        exit 1
    fi
    
    if [[ ! -f "$BUILD_DIR/bin/swift-reflection-dump" ]]; then
        log_error "swift-reflection-dump not found in $BUILD_DIR/bin/"
        log_info "Please build Swift with: utils/build-script"
        exit 1
    fi
    
    # Check platform
    if [[ "$(uname)" != "Darwin" ]]; then
        log_warning "This script is designed for macOS. Some tests may not work on other platforms."
    fi
    
    log_info "Prerequisites check passed"
}

# Create test binaries
create_test_binaries() {
    log_info "Creating test binaries..."
    
    cat > "$TEMP_DIR/TestTypes.swift" << 'EOF'
import Foundation

public protocol TestProtocol {
    associatedtype Element
}

public struct SimpleStruct {
    public var intValue: Int
    public var stringValue: String
}

public class TestClass {
    public var property: String = "test"
    public var number: Int = 42
}

public struct GenericStruct<T: TestProtocol> {
    public var value: T
    public var element: T.Element
}

public enum TestEnum {
    case simple
    case withValue(String)
}
EOF
    
    # Build with chained fixups (default on modern systems)
    run_test "Build with chained fixups" \
        "xcrun swiftc -emit-library '$TEMP_DIR/TestTypes.swift' -o '$TEMP_DIR/test_chained.dylib'"
    
    # Build with legacy bind info
    run_test "Build with legacy fixups" \
        "xcrun swiftc -emit-library '$TEMP_DIR/TestTypes.swift' -Xlinker -no_fixup_chains -o '$TEMP_DIR/test_legacy.dylib'"
}

# Verify binary formats
verify_binary_formats() {
    log_info "Verifying binary formats..."
    
    # Check chained fixups format
    if otool -l "$TEMP_DIR/test_chained.dylib" | grep -q "LC_DYLD_CHAINED_FIXUPS"; then
        echo -e "Chained binary format... ${GREEN}✓${NC}"
        ((PASSED++))
    else
        echo -e "Chained binary format... ${RED}✗${NC} (Expected LC_DYLD_CHAINED_FIXUPS)"
        ((FAILED++))
    fi
    
    # Check legacy format
    if ! otool -l "$TEMP_DIR/test_legacy.dylib" | grep -q "LC_DYLD_CHAINED_FIXUPS"; then
        echo -e "Legacy binary format... ${GREEN}✓${NC}"
        ((PASSED++))
    else
        echo -e "Legacy binary format... ${RED}✗${NC} (Should not have LC_DYLD_CHAINED_FIXUPS)"
        ((FAILED++))
    fi
}

# Test reflection dump functionality
test_reflection_dump() {
    log_info "Testing reflection dump functionality..."
    
    local SWIFT_REFLECTION_DUMP="$BUILD_DIR/bin/swift-reflection-dump"
    
    # Test chained binary
    run_test "Dump chained binary" \
        "'$SWIFT_REFLECTION_DUMP' '$TEMP_DIR/test_chained.dylib' -arch $(uname -m) -dump-reflection-sections"
    
    # Test legacy binary
    run_test "Dump legacy binary" \
        "'$SWIFT_REFLECTION_DUMP' '$TEMP_DIR/test_legacy.dylib' -arch $(uname -m) -dump-reflection-sections"
    
    # Compare outputs
    "$SWIFT_REFLECTION_DUMP" "$TEMP_DIR/test_chained.dylib" -arch "$(uname -m)" -dump-reflection-sections > "$TEMP_DIR/chained.out" 2>&1
    "$SWIFT_REFLECTION_DUMP" "$TEMP_DIR/test_legacy.dylib" -arch "$(uname -m)" -dump-reflection-sections > "$TEMP_DIR/legacy.out" 2>&1
    
    run_test "Output comparison" \
        "diff '$TEMP_DIR/chained.out' '$TEMP_DIR/legacy.out'"
}

# Test diagnostic mode
test_diagnostic_mode() {
    log_info "Testing diagnostic mode..."
    
    local SWIFT_REFLECTION_DUMP="$BUILD_DIR/bin/swift-reflection-dump"
    
    # Run with diagnostics enabled
    SWIFT_REFLECTION_DUMP_DIAGNOSTICS=1 "$SWIFT_REFLECTION_DUMP" \
        "$TEMP_DIR/test_chained.dylib" -arch "$(uname -m)" -dump-reflection-sections \
        > "$TEMP_DIR/diag.out" 2>&1
    
    if grep -q "DIAGNOSTIC: Processing chained fixups" "$TEMP_DIR/diag.out"; then
        echo -e "Diagnostic mode (chained)... ${GREEN}✓${NC}"
        ((PASSED++))
    else
        echo -e "Diagnostic mode (chained)... ${RED}✗${NC}"
        ((FAILED++))
    fi
    
    # Test legacy diagnostic
    SWIFT_REFLECTION_DUMP_DIAGNOSTICS=1 "$SWIFT_REFLECTION_DUMP" \
        "$TEMP_DIR/test_legacy.dylib" -arch "$(uname -m)" -dump-reflection-sections \
        > "$TEMP_DIR/diag_legacy.out" 2>&1
    
    if grep -q "DIAGNOSTIC: Using legacy bind table" "$TEMP_DIR/diag_legacy.out"; then
        echo -e "Diagnostic mode (legacy)... ${GREEN}✓${NC}"
        ((PASSED++))
    else
        echo -e "Diagnostic mode (legacy)... ${RED}✗${NC}"
        ((FAILED++))
    fi
}

# Run lit tests
run_lit_tests() {
    log_info "Running lit tests..."
    
    if [[ -f "$SWIFT_SOURCE_ROOT/utils/run-test" ]]; then
        # Run chained fixups specific tests
        if "$SWIFT_SOURCE_ROOT/utils/run-test" \
            --build-dir "$BUILD_DIR" \
            "$SWIFT_SOURCE_ROOT/test/Reflection/chained_fixups.swift" > /dev/null 2>&1; then
            echo -e "Lit test (chained_fixups.swift)... ${GREEN}✓${NC}"
            ((PASSED++))
        else
            echo -e "Lit test (chained_fixups.swift)... ${RED}✗${NC}"
            ((FAILED++))
        fi
        
        # Run both formats test
        if "$SWIFT_SOURCE_ROOT/utils/run-test" \
            --build-dir "$BUILD_DIR" \
            "$SWIFT_SOURCE_ROOT/test/Reflection/typeref_lowering_both_formats.swift" > /dev/null 2>&1; then
            echo -e "Lit test (both_formats.swift)... ${GREEN}✓${NC}"
            ((PASSED++))
        else
            echo -e "Lit test (both_formats.swift)... ${RED}✗${NC}"
            ((FAILED++))
        fi
    else
        log_warning "run-test not found, skipping lit tests"
        ((SKIPPED+=2))
    fi
}

# Test with real Swift packages
test_real_packages() {
    log_info "Testing with real Swift packages (optional)..."
    
    # This is optional and can be slow
    if [[ "${SKIP_REAL_PACKAGES:-0}" == "1" ]]; then
        log_warning "Skipping real package tests (set SKIP_REAL_PACKAGES=0 to enable)"
        ((SKIPPED++))
        return
    fi
    
    # Test with swift-argument-parser if available
    if command -v swift build > /dev/null 2>&1; then
        local TEST_PKG_DIR="$TEMP_DIR/test-package"
        mkdir -p "$TEST_PKG_DIR"
        
        cat > "$TEST_PKG_DIR/Package.swift" << 'EOF'
// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "TestPackage",
    products: [
        .library(name: "TestPackage", targets: ["TestPackage"]),
    ],
    targets: [
        .target(name: "TestPackage"),
    ]
)
EOF
        
        mkdir -p "$TEST_PKG_DIR/Sources/TestPackage"
        echo 'public struct TestPackage { public init() {} }' > "$TEST_PKG_DIR/Sources/TestPackage/TestPackage.swift"
        
        if (cd "$TEST_PKG_DIR" && swift build -c release) > /dev/null 2>&1; then
            local BUILT_LIB=$(find "$TEST_PKG_DIR/.build" -name "*.dylib" -o -name "*.so" | head -1)
            if [[ -n "$BUILT_LIB" ]]; then
                run_test "Real package test" \
                    "'$BUILD_DIR/bin/swift-reflection-dump' '$BUILT_LIB' -arch '$(uname -m)' -dump-reflection-sections"
            fi
        else
            log_warning "Could not build test package"
            ((SKIPPED++))
        fi
    else
        log_warning "Swift not available, skipping package test"
        ((SKIPPED++))
    fi
}

# Cleanup
cleanup() {
    log_info "Cleaning up..."
    rm -rf "$TEMP_DIR"
}

# Main execution
main() {
    echo "========================================"
    echo "DYLD Chained Fixups Implementation Test"
    echo "========================================"
    echo
    
    check_prerequisites
    create_test_binaries
    verify_binary_formats
    test_reflection_dump
    test_diagnostic_mode
    run_lit_tests
    test_real_packages
    
    echo
    echo "========================================"
    echo "Test Results:"
    echo -e "  Passed:  ${GREEN}$PASSED${NC}"
    echo -e "  Failed:  ${RED}$FAILED${NC}"
    echo -e "  Skipped: ${YELLOW}$SKIPPED${NC}"
    echo "========================================"
    
    cleanup
    
    if [[ $FAILED -eq 0 ]]; then
        log_info "All tests passed! ✨"
        exit 0
    else
        log_error "Some tests failed. Please review the implementation."
        exit 1
    fi
}

# Trap cleanup on exit
trap cleanup EXIT

# Run main
main "$@"