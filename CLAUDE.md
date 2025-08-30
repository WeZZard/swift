# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the Swift programming language compiler repository, containing the Swift compiler frontend, standard library, runtime, and associated tools. The codebase is primarily written in C++ (compiler) and Swift (standard library).

## Building the Project

### Prerequisites
Before building, ensure you have cloned all required repositories using:
```bash
utils/update-checkout --clone-with-ssh  # or --clone for HTTPS
```

### Common Build Commands

**Basic debug build:**
```bash
utils/build-script --skip-build-benchmarks --skip-ios --skip-tvos --skip-watchos --skip-xros
```

**Incremental build with Ninja (faster for development):**
```bash
utils/build-script --skip-build-benchmarks --skip-ios --skip-tvos --skip-watchos --skip-xros --ninja
```

**Release build with assertions:**
```bash
utils/build-script --release-debuginfo --assertions
```

**Build with specific architecture on macOS:**
```bash
utils/build-script --swift-darwin-supported-archs "$(uname -m)"
```

## Testing

### Running Tests

**Run primary test suite:**
```bash
utils/build-script --test
```

**Run validation tests (more comprehensive):**
```bash
utils/build-script --validation-test
```

**Run specific tests using run-test:**
```bash
utils/run-test --build-dir ../build/Ninja-DebugAssert/swift-linux-x86_64 test/Parse/
```

**Run a single test file:**
```bash
utils/run-test --build-dir ../build/Ninja-DebugAssert/swift-linux-x86_64 test/Parse/mytest.swift
```

### Test Categories
- **Primary tests** (`test/`): Core functionality tests
- **Validation tests** (`validation-test/`): Extended test suite
- **Unit tests** (`unittests/`): C++ unit tests
- **Long tests**: Tests marked with `REQUIRES: long_test`
- **Stress tests**: Tests marked with `REQUIRES: stress_test`

## Code Architecture

### Compiler Components

**Frontend (`lib/`):**
- `AST/`: Abstract Syntax Tree implementation
- `Parse/`: Swift parser
- `Sema/`: Semantic analysis
- `SIL/`: Swift Intermediate Language
- `SILGen/`: SIL generation from AST
- `SILOptimizer/`: SIL optimization passes
- `IRGen/`: LLVM IR generation from SIL
- `ClangImporter/`: Clang module importing for C/Objective-C interop
- `Frontend/`: Frontend coordination and driver interfaces

**Runtime (`stdlib/`):**
- `public/core/`: Core standard library
- `public/runtime/`: Swift runtime implementation
- `public/Platform/`: Platform-specific implementations
- `public/Concurrency/`: Async/await and actor runtime

**Key Intermediate Representations:**
1. **AST** (Abstract Syntax Tree): Initial parsed representation
2. **SIL** (Swift Intermediate Language): High-level SSA form for Swift-specific optimizations
3. **LLVM IR**: Low-level representation for LLVM optimization and code generation

### Build System

The project uses CMake as its build system with custom Python scripts:
- `utils/build-script`: Main build driver
- `utils/build-script-impl`: Implementation details
- `CMakeLists.txt` files throughout define build targets

## Development Workflow

### Making Changes

1. **Edit-build-test cycle for compiler changes:**
   ```bash
   # Edit files in lib/
   utils/build-script --skip-build-benchmarks --skip-ios --skip-tvos --skip-watchos --skip-xros
   utils/run-test --build-dir ../build/Ninja-DebugAssert/swift-macosx-x86_64 test/path/to/test.swift
   ```

2. **Using custom compiler:**
   ```bash
   export SWIFT_EXEC=/path/to/build/bin/swiftc
   swift build  # Uses custom compiler
   ```

3. **Debugging compiler crashes:**
   - Look for crash reproducers in test cases
   - Use `--debug` flags in build-script for debug builds
   - LLDB can be used to debug the compiler itself

### CI and Pull Request Testing

Test your changes before submitting PRs using @swift-ci commands:
- `@swift-ci Please smoke test`: Quick validation
- `@swift-ci Please test`: Full validation testing
- `@swift-ci Please benchmark`: Performance testing

## Important Files and Directories

- `include/swift/`: Public headers
- `lib/`: Compiler implementation
- `stdlib/`: Standard library and runtime
- `test/`: Test suite
- `docs/`: Documentation
- `utils/`: Build scripts and utilities
- `benchmark/`: Performance benchmarks
- `validation-test/`: Extended validation tests

## Key Development Notes

- The compiler is built in multiple stages (bootstrap)
- SIL is the key intermediate representation for Swift-specific optimizations
- Tests use LLVM's lit testing framework
- Always run tests before committing changes
- For iOS/tvOS/watchOS development, simulators are built by default unless skipped