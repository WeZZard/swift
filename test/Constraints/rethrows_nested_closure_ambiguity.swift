// RUN: %target-typecheck-verify-swift -verify-ignore-unrelated

// This test verifies that calling Array.remove(at:) inside nested closures
// with rethrows functions does not produce a false ambiguity error.
// The constraint solver was generating multiple solutions with the same
// overload choice but different type bindings for closure result types,
// causing spurious "ambiguous use of 'remove(at:)'" errors.

// Test 1: Basic nested closure with rethrows and generic result
@discardableResult
func closureWithGenericResult<T>(_ body: () throws -> T) rethrows -> T {
    try body()
}

func actionWithVoidReturn(_ body: () throws -> Void) rethrows {
    try body()
}

func testNestedClosureRemove() {
    var items = [1, 2, 3]

    // This used to fail with: "Ambiguous use of 'remove(at:)'"
    // Both Array.remove(at:) and RangeReplaceableCollection.remove(at:)
    // were being reported as candidates
    actionWithVoidReturn {
        closureWithGenericResult {
            items.remove(at: 0)
        }
    }
}

// Test 2: Multiple levels of nesting
func testMultipleLevelsOfNesting() {
    var items = [1, 2, 3]

    actionWithVoidReturn {
        closureWithGenericResult {
            closureWithGenericResult {
                items.remove(at: 0)
            }
        }
    }
}

// Test 3: With explicit type annotation (should also work)
func testWithExplicitType() {
    var items = [1, 2, 3]

    actionWithVoidReturn {
        closureWithGenericResult { () -> Int in
            items.remove(at: 0)
        }
    }
}

// Test 4: Without nesting (should work as before)
func testWithoutNesting() {
    var items = [1, 2, 3]

    _ = closureWithGenericResult {
        items.remove(at: 0)
    }
}

// Test 5: Using DispatchQueue (common real-world pattern)
import Dispatch

@discardableResult
func withAnimation<Result>(_ body: () throws -> Result) rethrows -> Result {
    try body()
}

func testDispatchQueuePattern() {
    var opacities: [Double] = [0, 0.5, 1.0]
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        withAnimation {
            opacities.remove(at: 2)
        }
    }
}
