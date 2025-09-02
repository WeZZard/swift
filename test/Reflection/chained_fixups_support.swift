// RUN: %empty-directory(%t)
// RUN: echo "import Foundation; public class Test { public let value = NSString() }" > %t/test.swift
// RUN: %target-build-swift -emit-library %t/test.swift -o %t/libtest.dylib
// RUN: %target-swift-reflection-dump %t/libtest.dylib > %t/output.txt
// RUN: %FileCheck %s < %t/output.txt
// REQUIRES: objc_interop

// This test verifies swift-reflection-dump handles binaries with DYLD chained fixups
// (iOS 15+/macOS 12+) without crashing. The actual fixup processing is tested by
// checking that the tool completes successfully.

// CHECK: FIELDS:
// CHECK: Test
// CHECK-DAG: value

// The test passes if swift-reflection-dump processes the binary without
// "unhandled Error" crashes that would occur without proper fixupTable() handling