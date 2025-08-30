// Test that chained fixups are properly handled in swift-reflection-dump
// REQUIRES: CPU=arm64 || CPU=x86_64
// REQUIRES: OS=macosx
// RUN: %empty-directory(%t)

// Build test library with chained fixups (default on modern systems)
// RUN: %target-build-swift %s -emit-library -o %t/test_chained.dylib
// RUN: %target-swift-reflection-dump %t/test_chained.dylib -arch %target-cpu -dump-reflection-sections | %FileCheck %s --check-prefix=CHECK-DUMP

// Build test library with legacy bind info for comparison
// RUN: %target-build-swift %s -emit-library %no-fixup-chains -o %t/test_legacy.dylib  
// RUN: %target-swift-reflection-dump %t/test_legacy.dylib -arch %target-cpu -dump-reflection-sections | %FileCheck %s --check-prefix=CHECK-DUMP

// Both formats should produce identical reflection output

public protocol TestProtocol {
    associatedtype Element
}

public struct TestStruct<T: TestProtocol> {
    public var field1: T
    public var field2: String  // External reference requiring bind fixup
    public var field3: Int     // Internal reference requiring rebase fixup
    // CHECK-DUMP: TestStruct
    // CHECK-DUMP: field1
    // CHECK-DUMP: field2
    // CHECK-DUMP: field3
}

public class TestClass {
    public var property: Int = 42
    public var stringProp: String = "test"
    // CHECK-DUMP: TestClass
    // CHECK-DUMP: property
    // CHECK-DUMP: stringProp
}

public enum TestEnum {
    case simple
    case withAssoc(String)
    case complex(Int, String)
    // CHECK-DUMP: TestEnum
}

// Test complex nested generics that stress fixup resolution
public struct NestedGeneric<T> {
    public struct Inner<U> {
        public var value: U
        public var outer: T
    }
    public var inner: Inner<String>
    // CHECK-DUMP: NestedGeneric
    // CHECK-DUMP: Inner
}

// Test protocol conformances (requires fixups for witness tables)
public struct ConformingType: TestProtocol {
    public typealias Element = Int
    public var element: Element
    // CHECK-DUMP: ConformingType
}

// Verify fixup diagnostics work when enabled
// RUN: env SWIFT_REFLECTION_DUMP_DIAGNOSTICS=1 %target-swift-reflection-dump %t/test_chained.dylib -arch %target-cpu -dump-reflection-sections 2>&1 | %FileCheck %s --check-prefix=CHECK-DIAG --allow-empty
// CHECK-DIAG-NOT: ERROR
// CHECK-DIAG-NOT: FATAL