#!/bin/bash

# Comprehensive test script for chained fixups implementation
# This runs all tests related to the chained fixups support

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWIFT_SOURCE_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test categories
declare -a TEST_CATEGORIES=(
    "lit_tests"
    "validation_tests"
    "unit_tests"
    "benchmarks"
    "real_packages"
)

# Test results
declare -A TEST_RESULTS

log_section() {
    echo
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Run lit tests
run_lit_tests() {
    log_section "Running Lit Tests"
    
    local tests=(
        "test/Reflection/chained_fixups.swift"
        "test/Reflection/typeref_lowering_both_formats.swift"
        "test/Reflection/chained_fixups_stress.swift"
        "test/Reflection/typeref_lowering.swift"
        "test/Reflection/typeref_decoding.swift"
    )
    
    local passed=0
    local failed=0
    
    for test in "${tests[@]}"; do
        echo -n "Testing $(basename "$test")... "
        if "$SWIFT_SOURCE_ROOT/utils/run-test" \
            --build-dir "$BUILD_DIR" \
            "$SWIFT_SOURCE_ROOT/$test" > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
            ((passed++))
        else
            echo -e "${RED}✗${NC}"
            ((failed++))
        fi
    done
    
    TEST_RESULTS["lit_tests"]="Passed: $passed, Failed: $failed"
    return $failed
}

# Run validation tests
run_validation_tests() {
    log_section "Running Validation Tests"
    
    if [[ -f "$SWIFT_SOURCE_ROOT/validation-test/Reflection/chained_fixups_validation.test-sh" ]]; then
        if bash "$SWIFT_SOURCE_ROOT/validation-test/Reflection/chained_fixups_validation.test-sh"; then
            echo -e "${GREEN}Validation tests passed${NC}"
            TEST_RESULTS["validation_tests"]="Passed"
            return 0
        else
            echo -e "${RED}Validation tests failed${NC}"
            TEST_RESULTS["validation_tests"]="Failed"
            return 1
        fi
    else
        log_warning "Validation test not found"
        TEST_RESULTS["validation_tests"]="Skipped"
        return 0
    fi
}

# Run unit tests
run_unit_tests() {
    log_section "Running Unit Tests"
    
    local unit_test_binary="$BUILD_DIR/unittests/StaticMirror/SwiftStaticMirrorTests"
    
    if [[ -f "$unit_test_binary" ]]; then
        # Create test binaries for unit tests
        local test_dir=$(mktemp -d)
        
        # Create simple test binary with chained fixups
        cat > "$test_dir/test.swift" << 'EOF'
public struct TestStruct {
    public var x: Int
    public var y: String
}
EOF
        swiftc -emit-library "$test_dir/test.swift" -o "$test_dir/chained.dylib"
        swiftc -emit-library "$test_dir/test.swift" -Xlinker -no_fixup_chains -o "$test_dir/legacy.dylib"
        
        # Set environment variables for tests
        export SWIFT_TEST_CHAINED_BINARY="$test_dir/chained.dylib"
        export SWIFT_TEST_LEGACY_BINARY="$test_dir/legacy.dylib"
        
        if "$unit_test_binary" --gtest_filter="ChainedFixups*"; then
            echo -e "${GREEN}Unit tests passed${NC}"
            TEST_RESULTS["unit_tests"]="Passed"
            rm -rf "$test_dir"
            return 0
        else
            echo -e "${RED}Unit tests failed${NC}"
            TEST_RESULTS["unit_tests"]="Failed"
            rm -rf "$test_dir"
            return 1
        fi
    else
        log_warning "Unit test binary not found"
        TEST_RESULTS["unit_tests"]="Skipped"
        return 0
    fi
}

# Run benchmarks
run_benchmarks() {
    log_section "Running Benchmarks"
    
    local benchmark_driver="$BUILD_DIR/bin/Benchmark_Driver"
    
    if [[ -f "$benchmark_driver" ]]; then
        if "$benchmark_driver" run \
            --filter ChainedFixupsReflection \
            --num-iters 5 \
            --output-dir "$SWIFT_SOURCE_ROOT/benchmark-results/"; then
            echo -e "${GREEN}Benchmarks completed${NC}"
            
            # Show summary
            if [[ -f "$SWIFT_SOURCE_ROOT/benchmark-results/result.json" ]]; then
                echo "Benchmark results saved to benchmark-results/"
            fi
            
            TEST_RESULTS["benchmarks"]="Completed"
            return 0
        else
            echo -e "${RED}Benchmarks failed${NC}"
            TEST_RESULTS["benchmarks"]="Failed"
            return 1
        fi
    else
        log_warning "Benchmark driver not found"
        TEST_RESULTS["benchmarks"]="Skipped"
        return 0
    fi
}

# Test with real packages
test_real_packages() {
    log_section "Testing with Real Packages"
    
    if ! command -v swift > /dev/null 2>&1; then
        log_warning "Swift not available, skipping package tests"
        TEST_RESULTS["real_packages"]="Skipped"
        return 0
    fi
    
    local packages=(
        "https://github.com/apple/swift-argument-parser"
        "https://github.com/apple/swift-collections"
    )
    
    local passed=0
    local failed=0
    local test_dir=$(mktemp -d)
    
    for package_url in "${packages[@]}"; do
        local package_name=$(basename "$package_url" .git)
        echo -n "Testing $package_name... "
        
        if git clone --depth 1 "$package_url" "$test_dir/$package_name" > /dev/null 2>&1; then
            if (cd "$test_dir/$package_name" && swift build -c release) > /dev/null 2>&1; then
                # Find and test built libraries
                local lib_found=false
                for lib in $(find "$test_dir/$package_name/.build" -name "*.dylib" -o -name "*.so"); do
                    if "$BUILD_DIR/bin/swift-reflection-dump" "$lib" \
                        -arch "$(uname -m)" -dump-reflection-sections > /dev/null 2>&1; then
                        lib_found=true
                        break
                    fi
                done
                
                if $lib_found; then
                    echo -e "${GREEN}✓${NC}"
                    ((passed++))
                else
                    echo -e "${RED}✗${NC}"
                    ((failed++))
                fi
            else
                echo -e "${YELLOW}Build failed${NC}"
                ((failed++))
            fi
        else
            echo -e "${YELLOW}Clone failed${NC}"
            ((failed++))
        fi
    done
    
    rm -rf "$test_dir"
    TEST_RESULTS["real_packages"]="Passed: $passed, Failed: $failed"
    return $failed
}

# Print summary
print_summary() {
    log_section "Test Summary"
    
    echo "Test Results:"
    for category in "${TEST_CATEGORIES[@]}"; do
        local result="${TEST_RESULTS[$category]:-Not run}"
        local color=$GREEN
        
        if [[ "$result" == *"Failed"* ]]; then
            color=$RED
        elif [[ "$result" == *"Skipped"* ]]; then
            color=$YELLOW
        fi
        
        printf "  %-20s: %b%s%b\n" "$category" "$color" "$result" "$NC"
    done
}

# Main execution
main() {
    log_section "Chained Fixups Comprehensive Test Suite"
    
    # Check for build directory
    if [[ -z "${BUILD_DIR:-}" ]]; then
        BUILD_DIR="$SWIFT_SOURCE_ROOT/../build/Ninja-DebugAssert/swift-macosx-$(uname -m)"
    fi
    
    if [[ ! -d "$BUILD_DIR" ]]; then
        log_error "Build directory not found: $BUILD_DIR"
        log_info "Please build Swift first or set BUILD_DIR environment variable"
        exit 1
    fi
    
    log_info "Using build directory: $BUILD_DIR"
    
    # Run tests
    local total_failures=0
    
    run_lit_tests || ((total_failures+=$?))
    run_validation_tests || ((total_failures+=$?))
    run_unit_tests || ((total_failures+=$?))
    run_benchmarks || ((total_failures+=$?))
    
    # Optional: test with real packages
    if [[ "${SKIP_REAL_PACKAGES:-0}" != "1" ]]; then
        test_real_packages || ((total_failures+=$?))
    fi
    
    # Print summary
    print_summary
    
    echo
    if [[ $total_failures -eq 0 ]]; then
        log_info "All tests passed! 🎉"
        exit 0
    else
        log_error "Some tests failed (failures: $total_failures)"
        exit 1
    fi
}

# Handle arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build-dir)
            BUILD_DIR="$2"
            shift 2
            ;;
        --skip-benchmarks)
            unset TEST_CATEGORIES[3]
            shift
            ;;
        --skip-real-packages)
            SKIP_REAL_PACKAGES=1
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --build-dir DIR         Specify build directory"
            echo "  --skip-benchmarks       Skip benchmark tests"
            echo "  --skip-real-packages    Skip testing with real packages"
            echo "  --help                  Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

main