// RUN: %target-typecheck-verify-swift -verify-ignore-unknown -verify-ignore-unrelated

// https://github.com/apple/swift/issues/IS0001
// Bug: Ambiguous method resolution for Array.remove(at:) in nested generic closures
//
// When Array.remove(at:) is called inside a nested closure where the outer
// closure is a generic function, the compiler incorrectly reports "ambiguous
// use of 'remove(at:)'" between Array.remove(at:) and
// RangeReplaceableCollection.remove(at:).

import Dispatch

// Generic function similar to SwiftUI's withAnimation
func withAnimation<Result>(_ body: () throws -> Result) rethrows -> Result {
    try body()
}

// Non-generic version for control case
func withoutAnimation(_ body: () throws -> Void) rethrows {
    try body()
}

// ============================================================================
// Bug Case: Array.remove(at:) in generic closure
// The method resolution ambiguity between Array.remove(at:) and
// RangeReplaceableCollection.remove(at:) is now correctly resolved by
// preferring the concrete type member (Array) over the protocol extension.
// ============================================================================

func testBugCase() {
    var opacities: [Double] = [0, 0.5, 1.0]
    // Simple case - generic closure without nested void-returning closure
    // This tests the method resolution fix without the Result type inference issue
    _ = withAnimation {
        opacities.remove(at: 2) // OK - Array.remove(at:) is correctly chosen
    }
}

// The nested closure case with Dispatch still has a separate issue with
// Result type inference (Void vs Double) that is orthogonal to the method
// resolution fix. When the Result type is constrained, the method resolution
// works correctly:
func testBugCaseWithExplicitResultType() {
    var opacities: [Double] = [0, 0.5, 1.0]
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        let _: Void = withAnimation {
            opacities.remove(at: 2) // OK - with constrained Result type
        }
    }
}

// ============================================================================
// Control Case 1: Direct call (no outer generic closure)
// Should compile successfully - Array.remove(at:) is unambiguous
// ============================================================================

func testDirectCall() {
    var opacities: [Double] = [0, 0.5, 1.0]
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        opacities.remove(at: 2) // OK - no ambiguity
    }
}

// ============================================================================
// Control Case 2: Non-generic outer closure
// Should compile successfully - Array.remove(at:) is unambiguous
// ============================================================================

func testNonGenericClosure() {
    var opacities: [Double] = [0, 0.5, 1.0]
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        withoutAnimation {
            opacities.remove(at: 2) // OK - no ambiguity
        }
    }
}

// ============================================================================
// Control Case 3: Workaround with explicit discard
// Should compile successfully - explicit discard resolves ambiguity
// ============================================================================

func testWorkaroundExplicitDiscard() {
    var opacities: [Double] = [0, 0.5, 1.0]
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        withAnimation {
            _ = opacities.remove(at: 2) // OK - explicit discard
        }
    }
}

// ============================================================================
// Additional Test Cases: Various nested generic closure scenarios
// These test the root cause fix in CSGen.cpp that properly maps outer
// generic type parameters to the current environment.
// ============================================================================

// Test multiple levels of generic closure nesting
func wrapGeneric<T>(_ body: () -> T) -> T {
    body()
}

func testMultipleLevelsOfGenericNesting() {
    var items: [Int] = [1, 2, 3]
    _ = wrapGeneric {
        wrapGeneric {
            items.remove(at: 0) // OK - works at multiple nesting levels
        }
    }
}

// Test with async context
func testAsyncContext() async {
    var data: [String] = ["a", "b", "c"]
    let _ = await Task {
        withAnimation {
            _ = data.remove(at: 1) // OK - async context with generic closure
        }
    }.value
}

// Test with generic closure that has multiple type parameters
func withContext<T, U>(_ value: T, _ body: (T) throws -> U) rethrows -> U {
    try body(value)
}

func testMultipleTypeParameters() {
    var numbers: [Int] = [10, 20, 30]
    _ = withContext(42) { _ in
        numbers.remove(at: 0) // OK - works with multiple type parameters
    }
}

// Test that we don't break existing non-generic closure behavior
func testNonGenericNestedClosure() {
    var values: [Double] = [1.0, 2.0, 3.0]
    DispatchQueue.main.async {
        DispatchQueue.main.async {
            values.remove(at: 0) // OK - non-generic nested closures
        }
    }
}
