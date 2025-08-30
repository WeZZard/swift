// Test edge cases for chained fixups support
// RUN: %empty-directory(%t)
// REQUIRES: OS=macosx

// === Test 1: Empty library ===
// RUN: echo "// Empty" | %target-swiftc -emit-library -o %t/empty_chained.dylib -
// RUN: echo "// Empty" | %target-swiftc -emit-library %no-fixup-chains -o %t/empty_legacy.dylib -
// RUN: %target-swift-reflection-dump %t/empty_chained.dylib -arch %target-cpu -dump-reflection-sections 2>&1 | %FileCheck %s --check-prefix=EMPTY --allow-empty
// RUN: %target-swift-reflection-dump %t/empty_legacy.dylib -arch %target-cpu -dump-reflection-sections 2>&1 | %FileCheck %s --check-prefix=EMPTY --allow-empty
// EMPTY-NOT: ERROR
// EMPTY-NOT: FATAL

// === Test 2: Library with only private types ===
// RUN: %target-build-swift %s -DPRIVATE_ONLY -emit-library -o %t/private_chained.dylib
// RUN: %target-build-swift %s -DPRIVATE_ONLY -emit-library %no-fixup-chains -o %t/private_legacy.dylib
// RUN: %target-swift-reflection-dump %t/private_chained.dylib -arch %target-cpu -dump-reflection-sections | %FileCheck %s --check-prefix=PRIVATE --allow-empty
// RUN: %target-swift-reflection-dump %t/private_legacy.dylib -arch %target-cpu -dump-reflection-sections | %FileCheck %s --check-prefix=PRIVATE --allow-empty

#if PRIVATE_ONLY
private struct PrivateStruct {
    var x: Int
}

private class PrivateClass {
    var y: String = ""
}

private enum PrivateEnum {
    case a, b
}
// PRIVATE-NOT: PrivateStruct
// PRIVATE-NOT: PrivateClass
// PRIVATE-NOT: PrivateEnum
#endif

// === Test 3: Circular type references ===
// RUN: %target-build-swift %s -DCIRCULAR -emit-library -o %t/circular_chained.dylib
// RUN: %target-build-swift %s -DCIRCULAR -emit-library %no-fixup-chains -o %t/circular_legacy.dylib
// RUN: %target-swift-reflection-dump %t/circular_chained.dylib -arch %target-cpu -dump-reflection-sections | %FileCheck %s --check-prefix=CIRCULAR
// RUN: %target-swift-reflection-dump %t/circular_legacy.dylib -arch %target-cpu -dump-reflection-sections | %FileCheck %s --check-prefix=CIRCULAR

#if CIRCULAR
public class Node {
    public var next: Node?
    public var value: Int = 0
    // CIRCULAR: Node
    // CIRCULAR: next
    // CIRCULAR: value
}

public struct LinkedList {
    public var head: Node?
    // CIRCULAR: LinkedList
    // CIRCULAR: head
}
#endif

// === Test 4: Maximum nesting depth ===
// RUN: %target-build-swift %s -DMAX_NESTING -emit-library -o %t/nesting_chained.dylib
// RUN: %target-build-swift %s -DMAX_NESTING -emit-library %no-fixup-chains -o %t/nesting_legacy.dylib
// RUN: %target-swift-reflection-dump %t/nesting_chained.dylib -arch %target-cpu -dump-reflection-sections | %FileCheck %s --check-prefix=NESTING
// RUN: %target-swift-reflection-dump %t/nesting_legacy.dylib -arch %target-cpu -dump-reflection-sections | %FileCheck %s --check-prefix=NESTING

#if MAX_NESTING
public struct L1<T> { public var v: T }
public struct L2<T> { public var v: L1<T> }
public struct L3<T> { public var v: L2<L1<T>> }
public struct L4<T> { public var v: L3<L2<L1<T>>> }
public struct L5<T> { public var v: L4<L3<L2<L1<T>>>> }
public struct L6<T> { public var v: L5<L4<L3<L2<L1<T>>>>> }
public struct L7<T> { public var v: L6<L5<L4<L3<L2<L1<T>>>>>> }
public struct L8<T> { public var v: L7<L6<L5<L4<L3<L2<L1<T>>>>>>> }
public struct L9<T> { public var v: L8<L7<L6<L5<L4<L3<L2<L1<T>>>>>>>> }
public struct L10<T> { public var v: L9<L8<L7<L6<L5<L4<L3<L2<L1<T>>>>>>>>> }
// NESTING: L10
// NESTING: L9
// NESTING: L8
#endif

// === Test 5: Special characters in type names ===
// RUN: %target-build-swift %s -DSPECIAL_CHARS -emit-library -o %t/special_chained.dylib
// RUN: %target-build-swift %s -DSPECIAL_CHARS -emit-library %no-fixup-chains -o %t/special_legacy.dylib
// RUN: %target-swift-reflection-dump %t/special_chained.dylib -arch %target-cpu -dump-reflection-sections | %FileCheck %s --check-prefix=SPECIAL
// RUN: %target-swift-reflection-dump %t/special_legacy.dylib -arch %target-cpu -dump-reflection-sections | %FileCheck %s --check-prefix=SPECIAL

#if SPECIAL_CHARS
public struct 你好世界 {
    public var 数值: Int = 0
    // SPECIAL: 你好世界
    // SPECIAL: 数值
}

public struct Émoji🎉 {
    public var 🔥: String = ""
    // SPECIAL: Émoji🎉
    // SPECIAL: 🔥
}
#endif

// === Test 6: Tuple types ===
// RUN: %target-build-swift %s -DTUPLES -emit-library -o %t/tuples_chained.dylib
// RUN: %target-build-swift %s -DTUPLES -emit-library %no-fixup-chains -o %t/tuples_legacy.dylib
// RUN: %target-swift-reflection-dump %t/tuples_chained.dylib -arch %target-cpu -dump-reflection-sections | %FileCheck %s --check-prefix=TUPLES
// RUN: %target-swift-reflection-dump %t/tuples_legacy.dylib -arch %target-cpu -dump-reflection-sections | %FileCheck %s --check-prefix=TUPLES

#if TUPLES
public struct TupleContainer {
    public var simple: (Int, String) = (0, "")
    public var named: (x: Int, y: String) = (0, "")
    public var nested: ((Int, String), (Bool, Double)) = ((0, ""), (false, 0.0))
    // TUPLES: TupleContainer
    // TUPLES: simple
    // TUPLES: named
    // TUPLES: nested
}
#endif

// === Test 7: Function types ===
// RUN: %target-build-swift %s -DFUNCTIONS -emit-library -o %t/functions_chained.dylib
// RUN: %target-build-swift %s -DFUNCTIONS -emit-library %no-fixup-chains -o %t/functions_legacy.dylib
// RUN: %target-swift-reflection-dump %t/functions_chained.dylib -arch %target-cpu -dump-reflection-sections | %FileCheck %s --check-prefix=FUNCTIONS
// RUN: %target-swift-reflection-dump %t/functions_legacy.dylib -arch %target-cpu -dump-reflection-sections | %FileCheck %s --check-prefix=FUNCTIONS

#if FUNCTIONS
public struct FunctionContainer {
    public var simple: () -> Void = {}
    public var withParams: (Int, String) -> Bool = { _, _ in false }
    public var throwing: () throws -> Int = { 0 }
    public var async: () async -> String = { "" }
    // FUNCTIONS: FunctionContainer
    // FUNCTIONS: simple
    // FUNCTIONS: withParams
    // FUNCTIONS: throwing
    // FUNCTIONS: async
}
#endif

// === Test 8: Existential types ===
// RUN: %target-build-swift %s -DEXISTENTIALS -emit-library -o %t/existentials_chained.dylib
// RUN: %target-build-swift %s -DEXISTENTIALS -emit-library %no-fixup-chains -o %t/existentials_legacy.dylib
// RUN: %target-swift-reflection-dump %t/existentials_chained.dylib -arch %target-cpu -dump-reflection-sections | %FileCheck %s --check-prefix=EXISTENTIALS
// RUN: %target-swift-reflection-dump %t/existentials_legacy.dylib -arch %target-cpu -dump-reflection-sections | %FileCheck %s --check-prefix=EXISTENTIALS

#if EXISTENTIALS
public protocol SomeProtocol {
    func doSomething()
}

public struct ExistentialContainer {
    public var anyValue: Any = 0
    public var anyObject: AnyObject? = nil
    public var protocolValue: any SomeProtocol? = nil
    // EXISTENTIALS: ExistentialContainer
    // EXISTENTIALS: anyValue
    // EXISTENTIALS: anyObject
    // EXISTENTIALS: protocolValue
}
#endif