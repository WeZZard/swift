# TRAE Project Rules

This file provides guidance to TRAE AI when working with code in this repository.

## Project Overview

This is the Swift Programming Language compiler and runtime repository. It contains the complete Swift toolchain including the compiler frontend, standard library, runtime, and supporting tools.

## Build System and Common Commands

### Primary Build Commands

The Swift project uses a Python-based build system with CMake as the underlying build generator:

- **Main build script**: `./utils/build-script` - The primary entry point for building Swift
- **Build with tests**: `./utils/build-script --test` - Build and run the primary test suite
- **Validation tests**: `./utils/build-script --validation-test` - Run comprehensive validation tests
- **Release build**: `./utils/build-script -R` - Build release configuration
- **Debug build**: `./utils/build-script` (default) - Build debug configuration
- **Toolchain build**: `./utils/build-toolchain <bundle-prefix>` - Build a complete toolchain

### Development Commands

- **Run specific tests**: `./utils/run-test --build-dir ${SWIFT_BUILD_DIR} <test-path>`
- **Ninja builds**: Use `ninja` in build directories for faster incremental builds
  - `ninja swift-frontend` - Build just the compiler frontend
  - `ninja -t targets` - List all available build targets
- **Bootstrapping modes**:
  - `--bootstrapping=hosttools` - Faster development builds (requires installed Swift toolchain)
  - `--bootstrapping-with-hostlibs` - Default mode for complete builds

### Testing Commands

- **Primary tests**: Located in `test/` directory
- **Validation tests**: Located in `validation-test/` directory  
- **Unit tests**: Located in `unittests/` directory
- **Lit-based testing**: Use `lit.py` directly for fine-grained test control
- **Test single file**: `${LLVM_SOURCE_ROOT}/utils/lit/lit.py -sv ${SWIFT_BUILD_DIR}/test-<platform>/Parse/`

## High-Level Architecture

### Core Compiler Components

The Swift compiler is organized into distinct phases and modules:

1. **Driver** (`lib/Driver/`) - Command-line interface and build orchestration
2. **Frontend** (`lib/Frontend/`) - Main compiler frontend coordination
3. **Parse** (`lib/Parse/`) - Lexical analysis and parsing
4. **AST** (`lib/AST/`) - Abstract Syntax Tree representation and analysis
5. **Sema** (`lib/Sema/`) - Semantic analysis and type checking
6. **SIL** (`lib/SIL/`) - Swift Intermediate Language representation
7. **SILGen** (`lib/SILGen/`) - AST to SIL lowering
8. **IRGen** (`lib/IRGen/`) - SIL to LLVM IR generation

### Key Directories

- **`lib/`** - Core compiler implementation
- **`include/swift/`** - Public headers and interfaces
- **`stdlib/`** - Swift standard library implementation
- **`test/`** - Primary test suite
- **`validation-test/`** - Extended validation tests
- **`utils/`** - Build scripts and development tools
- **`docs/`** - Comprehensive documentation
- **`tools/`** - Command-line tools and utilities

### Module Dependencies

The compiler follows a layered architecture:
- Basic utilities and support (`lib/Basic/`)
- AST and language semantics (`lib/AST/`, `lib/Sema/`)
- Intermediate representations (`lib/SIL/`, `lib/SILGen/`)
- Code generation (`lib/IRGen/`)
- Driver and tooling (`lib/Driver/`, `lib/Frontend/`)

## Logging and Debugging Practices

### Diagnostic System

Swift uses a sophisticated diagnostic system for error reporting:

- **Diagnostic definitions**: Located in `include/swift/AST/Diagnostics*.def` files
- **Diagnostic categories**: Parse, Sema, IRGen, Driver, Frontend, etc.
- **Diagnostic usage**: Use `diag::diagnostic_name` in source code
- **Diagnostic format**: `ERROR(identifier, category, "message format", (arg_types))`

### Debug Logging

- **LLVM Debug**: Use `LLVM_DEBUG(...)` instead of deprecated `DEBUG(...)` macro
- **Debug output**: Use `llvm::dbgs()` for debug streams
- **Debug categories**: Enable with `-debug-only=<category>` flag
- **Assertions**: Use `swift_assert()` for Swift-specific assertions

### Error Handling Patterns

- **DiagnosticEngine**: Central error reporting system
- **InFlightDiagnostic**: For building complex diagnostic messages
- **Error emission**: Use `diagnose()`, `emitError()`, `emitWarning()` methods
- **Diagnostic verification**: Tests can verify expected diagnostics with `// expected-error` comments

### Debugging Tools

- **AST dumping**: Use `-dump-ast` flag to examine AST structure
- **SIL dumping**: Use `-emit-sil` to examine SIL representation
- **Type checking**: Use `-debug-constraints` for constraint solver debugging
- **Incremental builds**: Use `-driver-show-incremental` to debug dependency tracking

## Development Practices

### Code Organization

- **Bridging**: C++ to Swift bridging code in `lib/*/Bridging/` directories
- **CMake structure**: Each major component has its own `CMakeLists.txt`
- **Header organization**: Public APIs in `include/swift/`, implementation details in `lib/`

### Testing Conventions

- **FileCheck tests**: Most tests use LLVM's FileCheck for output verification
- **RUN lines**: Tests specify compilation commands with `// RUN:` directives
- **Test organization**: Tests are organized by compiler phase and feature area
- **Negative tests**: Use `// expected-error` for tests that should fail

### Performance Considerations

- **Ninja builds**: Preferred for development due to faster incremental builds
- **Debug vs Release**: Use release builds for performance testing
- **Bootstrapping**: Use `hosttools` mode for faster development iteration
- **Parallel builds**: Build system automatically uses available CPU cores

## Key Documentation

Essential documentation for understanding the codebase:

- **`docs/README.md`** - Documentation index and organization
- **`docs/Testing.md`** - Comprehensive testing guide
- **`docs/Driver.md`** - Driver and compilation model explanation
- **`docs/DevelopmentTips.md`** - Development workflow optimization
- **`README.md`** - Project overview and getting started guide
- **`CONTRIBUTING.md`** - Contribution guidelines and process

## Build Troubleshooting

- **Clean builds**: Use `--clean` flag to `build-script` for clean rebuilds
- **Xcode version**: Ensure correct Xcode version for macOS builds
- **Reconfigure**: Use `--reconfigure` after Xcode updates
- **Build failures**: Check `docs/HowToGuides/GettingStarted.md#troubleshooting-build-issues`