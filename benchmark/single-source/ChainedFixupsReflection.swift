//===--- ChainedFixupsReflection.swift -----------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import TestsUtils
import Foundation

public let benchmarks = [
    BenchmarkInfo(
        name: "ReflectionDumpChainedSmall",
        runFunction: run_ReflectionDumpChainedSmall,
        tags: [.reflection, .metadata],
        setUpFunction: setUpSmall
    ),
    BenchmarkInfo(
        name: "ReflectionDumpLegacySmall",
        runFunction: run_ReflectionDumpLegacySmall,
        tags: [.reflection, .metadata],
        setUpFunction: setUpSmall
    ),
    BenchmarkInfo(
        name: "ReflectionDumpChainedLarge",
        runFunction: run_ReflectionDumpChainedLarge,
        tags: [.reflection, .metadata],
        setUpFunction: setUpLarge
    ),
    BenchmarkInfo(
        name: "ReflectionDumpLegacyLarge",
        runFunction: run_ReflectionDumpLegacyLarge,
        tags: [.reflection, .metadata],
        setUpFunction: setUpLarge
    ),
]

// Test binaries paths
var smallChainedBinary: String!
var smallLegacyBinary: String!
var largeChainedBinary: String!
var largeLegacyBinary: String!

// Small test library source
let smallLibrarySource = """
public struct SimpleStruct {
    public var x: Int
    public var y: String
}

public class SimpleClass {
    public var property: String = ""
}

public enum SimpleEnum {
    case a, b, c
}
"""

// Large test library source with many types
let largeLibrarySource = """
import Foundation

public protocol P0 { associatedtype T }
public protocol P1 { associatedtype T }
public protocol P2 { associatedtype T }
public protocol P3 { associatedtype T }
public protocol P4 { associatedtype T }

\(generateManyStructs(count: 100))
\(generateManyClasses(count: 50))
\(generateManyEnums(count: 30))

public struct ComplexGeneric<A: P0, B: P1, C: P2, D: P3, E: P4> {
    public var a: A
    public var b: B
    public var c: C
    public var d: D
    public var e: E
}
"""

func generateManyStructs(count: Int) -> String {
    (0..<count).map { i in
        """
        public struct Struct\(i) {
            public var field0: Int = 0
            public var field1: String = ""
            public var field2: Double = 0.0
            public var field3: Bool = false
            public var field4: [Int] = []
        }
        """
    }.joined(separator: "\n")
}

func generateManyClasses(count: Int) -> String {
    (0..<count).map { i in
        """
        public class Class\(i) {
            public var property0: String = ""
            public var property1: Int = 0
            public var property2: Date = Date()
        }
        """
    }.joined(separator: "\n")
}

func generateManyEnums(count: Int) -> String {
    (0..<count).map { i in
        """
        public enum Enum\(i) {
            case case0
            case case1(String)
            case case2(Int, String)
        }
        """
    }.joined(separator: "\n")
}

func buildTestBinary(source: String, output: String, useChainedFixups: Bool) {
    let sourceFile = "\(NSTemporaryDirectory())/\(UUID().uuidString).swift"
    try! source.write(toFile: sourceFile, atomically: true, encoding: .utf8)
    
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
    task.arguments = [
        "-emit-library",
        sourceFile,
        "-o", output
    ]
    
    if !useChainedFixups {
        task.arguments! += ["-Xlinker", "-no_fixup_chains"]
    }
    
    try! task.run()
    task.waitUntilExit()
    
    try! FileManager.default.removeItem(atPath: sourceFile)
}

func setUpSmall() {
    let tmpDir = NSTemporaryDirectory()
    smallChainedBinary = "\(tmpDir)/bench_small_chained.dylib"
    smallLegacyBinary = "\(tmpDir)/bench_small_legacy.dylib"
    
    if !FileManager.default.fileExists(atPath: smallChainedBinary) {
        buildTestBinary(source: smallLibrarySource, 
                       output: smallChainedBinary, 
                       useChainedFixups: true)
    }
    
    if !FileManager.default.fileExists(atPath: smallLegacyBinary) {
        buildTestBinary(source: smallLibrarySource, 
                       output: smallLegacyBinary, 
                       useChainedFixups: false)
    }
}

func setUpLarge() {
    let tmpDir = NSTemporaryDirectory()
    largeChainedBinary = "\(tmpDir)/bench_large_chained.dylib"
    largeLegacyBinary = "\(tmpDir)/bench_large_legacy.dylib"
    
    if !FileManager.default.fileExists(atPath: largeChainedBinary) {
        buildTestBinary(source: largeLibrarySource, 
                       output: largeChainedBinary, 
                       useChainedFixups: true)
    }
    
    if !FileManager.default.fileExists(atPath: largeLegacyBinary) {
        buildTestBinary(source: largeLibrarySource, 
                       output: largeLegacyBinary, 
                       useChainedFixups: false)
    }
}

func runReflectionDump(on binary: String) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift-reflection-dump")
    process.arguments = [binary, "-arch", "arm64", "-dump-reflection-sections"]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    
    try! process.run()
    process.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

@inline(never)
public func run_ReflectionDumpChainedSmall(_ n: Int) {
    for _ in 0..<n {
        blackHole(runReflectionDump(on: smallChainedBinary))
    }
}

@inline(never)
public func run_ReflectionDumpLegacySmall(_ n: Int) {
    for _ in 0..<n {
        blackHole(runReflectionDump(on: smallLegacyBinary))
    }
}

@inline(never)
public func run_ReflectionDumpChainedLarge(_ n: Int) {
    for _ in 0..<n {
        blackHole(runReflectionDump(on: largeChainedBinary))
    }
}

@inline(never)
public func run_ReflectionDumpLegacyLarge(_ n: Int) {
    for _ in 0..<n {
        blackHole(runReflectionDump(on: largeLegacyBinary))
    }
}

// Helper to measure fixup processing specifically
public func measureFixupProcessing() {
    let iterations = 100
    
    // Measure chained fixups
    let chainedStart = Date()
    for _ in 0..<iterations {
        _ = runReflectionDump(on: largeChainedBinary)
    }
    let chainedTime = Date().timeIntervalSince(chainedStart)
    
    // Measure legacy bind info
    let legacyStart = Date()
    for _ in 0..<iterations {
        _ = runReflectionDump(on: largeLegacyBinary)
    }
    let legacyTime = Date().timeIntervalSince(legacyStart)
    
    print("Performance comparison (\(iterations) iterations):")
    print("  Chained fixups: \(chainedTime)s (\(chainedTime/Double(iterations))s per iteration)")
    print("  Legacy bind:    \(legacyTime)s (\(legacyTime/Double(iterations))s per iteration)")
    print("  Ratio:          \(chainedTime/legacyTime)x")
}