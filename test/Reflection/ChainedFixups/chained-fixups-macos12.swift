// RUN: %empty-directory(%t)
// RUN: %target-build-swift -emit-library -emit-module %s -o %t/libTest.dylib -target arm64-apple-macos12.0
// RUN: %target-swift-reflection-dump %t/libTest.dylib | %FileCheck %s
// REQUIRES: OS=macosx
// REQUIRES: CPU=arm64

// This test verifies that swift-reflection-dump correctly processes
// binaries with DYLD chained fixups (macOS 12+/iOS 15+)

import Foundation

// External symbol reference that will create a chained fixup bind
public class TestClass {
    public let stringValue = NSString("ChainedFixupTest")
    
    public func testMethod() {
        print("Testing chained fixups")
    }
}

// CHECK: FIELDS:
// CHECK: TestClass
// CHECK: stringValue

// The test passes if:
// 1. swift-reflection-dump doesn't crash on the binary
// 2. It correctly extracts the reflection metadata
// 3. The chained fixups are properly processed (no unhandled errors)