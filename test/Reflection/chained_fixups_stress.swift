// Stress test for chained fixups with many relocations
// REQUIRES: stress_test
// REQUIRES: OS=macosx
// RUN: %empty-directory(%t)

// Test with large number of fixups
// RUN: %target-build-swift %s -emit-library -o %t/stress_chained.dylib
// RUN: %target-build-swift %s -emit-library %no-fixup-chains -o %t/stress_legacy.dylib
// RUN: %target-swift-reflection-dump %t/stress_chained.dylib -arch %target-cpu -dump-reflection-sections | %FileCheck %s
// RUN: %target-swift-reflection-dump %t/stress_legacy.dylib -arch %target-cpu -dump-reflection-sections | %FileCheck %s

import Foundation

// Generate many types requiring bind fixups (external references)
public struct ExternalRefs {
    public var s0: String = ""
    public var s1: Array<Int> = []
    public var s2: Dictionary<String, Int> = [:]
    public var s3: Set<String> = []
    public var s4: Data = Data()
    public var s5: URL? = nil
    public var s6: Date = Date()
    public var s7: UUID = UUID()
    public var s8: NSObject? = nil
    public var s9: NSString = ""
}

// Generate many types requiring rebase fixups (internal references)
public protocol P0 { associatedtype T0 }
public protocol P1 { associatedtype T1 }
public protocol P2 { associatedtype T2 }
public protocol P3 { associatedtype T3 }
public protocol P4 { associatedtype T4 }

public struct InternalRefs<A: P0, B: P1, C: P2, D: P3, E: P4> {
    public var a: A
    public var b: B
    public var c: C
    public var d: D
    public var e: E
    public var at: A.T0?
    public var bt: B.T1?
    public var ct: C.T2?
    public var dt: D.T3?
    public var et: E.T4?
}

// Generate deeply nested types
public struct Level1<T> { public var value: T }
public struct Level2<T> { public var value: Level1<T> }
public struct Level3<T> { public var value: Level2<Level1<T>> }
public struct Level4<T> { public var value: Level3<Level2<Level1<T>>> }
public struct Level5<T> { public var value: Level4<Level3<Level2<Level1<T>>>> }
public struct Level6<T> { public var value: Level5<Level4<Level3<Level2<Level1<T>>>>> }
public struct Level7<T> { public var value: Level6<Level5<Level4<Level3<Level2<Level1<T>>>>>> }
public struct Level8<T> { public var value: Level7<Level6<Level5<Level4<Level3<Level2<Level1<T>>>>>>> }

// Generate many protocol conformances
public protocol Proto0 { func method0() }
public protocol Proto1 { func method1() }
public protocol Proto2 { func method2() }
public protocol Proto3 { func method3() }
public protocol Proto4 { func method4() }
public protocol Proto5 { func method5() }
public protocol Proto6 { func method6() }
public protocol Proto7 { func method7() }
public protocol Proto8 { func method8() }
public protocol Proto9 { func method9() }

public struct ManyConformances: Proto0, Proto1, Proto2, Proto3, Proto4, 
                                Proto5, Proto6, Proto7, Proto8, Proto9 {
    public func method0() {}
    public func method1() {}
    public func method2() {}
    public func method3() {}
    public func method4() {}
    public func method5() {}
    public func method6() {}
    public func method7() {}
    public func method8() {}
    public func method9() {}
}

// Generate many enum cases
public enum LargeEnum {
    case case0, case1, case2, case3, case4
    case case5, case6, case7, case8, case9
    case case10(String), case11(Int), case12(Double)
    case case13(String, Int), case14(Int, Double)
    case case15(String, Int, Double)
    case case16(a: String, b: Int, c: Double, d: Bool)
    indirect case recursive(LargeEnum)
}

// CHECK: ExternalRefs
// CHECK: InternalRefs
// CHECK: Level8
// CHECK: ManyConformances
// CHECK: LargeEnum