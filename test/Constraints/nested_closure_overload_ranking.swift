// RUN: %target-typecheck-verify-swift

// Test for preferring concrete type members over protocol extension members
// in nested generic closure contexts.
//
// This test ensures that calling Array.remove(at:) inside nested closures
// combining async dispatch with generic functions does not produce a spurious
// "ambiguous use of 'remove(at:)'" error. The compiler should prefer Array's
// remove(at:) over RangeReplaceableCollection's remove(at:) even when the
// closure result type is an under-constrained type variable.

import Dispatch

// MARK: - Test Helpers

func withAnimation<Result>(_ body: () throws -> Result) rethrows -> Result {
    try body()
}

func genericWrapper<T>(_ body: () throws -> T) rethrows -> T {
    try body()
}

// MARK: - Original Bug Reproduction

// This is the original case that triggered the bug report.
// It should compile without any "ambiguous use of 'remove(at:)'" error.
func testOriginalBugCase() {
    var opacities: [Double] = [0, 0.5, 1.0]
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        withAnimation {
            opacities.remove(at: 2)
        }
    }
}

// MARK: - Variations

// Test with different array element types
func testWithIntArray() {
    var numbers: [Int] = [1, 2, 3]
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        withAnimation {
            numbers.remove(at: 0)
        }
    }
}

func testWithStringArray() {
    var strings: [String] = ["a", "b", "c"]
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        withAnimation {
            strings.remove(at: 1)
        }
    }
}

// Test with different nesting patterns
func testDoubleNesting() {
    var items: [Int] = [1, 2, 3]
    genericWrapper {
        withAnimation {
            items.remove(at: 0)
        }
    }
}

func testTripleNesting() {
    var items: [Int] = [1, 2, 3]
    DispatchQueue.main.async {
        genericWrapper {
            withAnimation {
                items.remove(at: 0)
            }
        }
    }
}

// Test with explicit return value assignment (the workaround)
// This should also continue to work
func testWithExplicitAssignment() {
    var items: [Int] = [1, 2, 3]
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        withAnimation {
            _ = items.remove(at: 0)
        }
    }
}

// Test with explicit type annotation
func testWithTypeAnnotation() {
    var items: [Int] = [1, 2, 3]
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        withAnimation { () -> Int in
            items.remove(at: 0)
        }
    }
}

// MARK: - Other RangeReplaceableCollection Methods

// Similar patterns with other methods that exist on both Array and
// RangeReplaceableCollection protocol extension

func testRemoveFirst() {
    var items: [Int] = [1, 2, 3]
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        withAnimation {
            items.removeFirst()
        }
    }
}

func testRemoveLast() {
    var items: [Int] = [1, 2, 3]
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        withAnimation {
            items.removeLast()
        }
    }
}

func testPopLast() {
    var items: [Int] = [1, 2, 3]
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        withAnimation {
            items.popLast()
        }
    }
}
