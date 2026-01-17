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
// Bug Case: Array.remove(at:) in nested generic closure
// ============================================================================

func testBugCase() {
    var opacities: [Double] = [0, 0.5, 1.0]
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        withAnimation {
            opacities.remove(at: 2) // expected-error {{ambiguous use of 'remove(at:)'}}
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
