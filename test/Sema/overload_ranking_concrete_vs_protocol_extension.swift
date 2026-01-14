// RUN: %target-typecheck-verify-swift

// Test that overload resolution correctly prefers concrete type members over
// protocol extension members, especially in nested generic closure contexts.
// This is a regression test for an issue where Array.remove(at:) was incorrectly
// reported as ambiguous with RangeReplaceableCollection.remove(at:) when called
// inside nested closures with generic parameters.

// Simulate the withAnimation-like pattern
func withAnimation<Result>(_ body: () throws -> Result) rethrows -> Result {
  try body()
}

// Test case 1: Nested closure with generic outer context
// This was the original failing case
func testNestedGenericClosure() {
  var opacities: [Double] = [0, 0.5, 1.0]

  // Simulate asyncAfter-like outer closure
  func asyncAfter(_ work: @escaping () -> Void) { work() }

  asyncAfter {
    withAnimation {
      // This should resolve to Array.remove(at:), not be ambiguous
      opacities.remove(at: 2)
    }
  }
}

// Test case 2: Direct call in generic closure (should work)
func testDirectGenericClosure() {
  var array: [Int] = [1, 2, 3]
  withAnimation {
    array.remove(at: 0)
  }
}

// Test case 3: Non-generic nested closure (should work)
func testNonGenericNestedClosure() {
  var array: [String] = ["a", "b", "c"]

  func asyncAfter(_ work: @escaping () -> Void) { work() }

  asyncAfter {
    // Non-generic inner closure
    let _ = {
      array.remove(at: 1)
    }()
  }
}

// Test case 4: Explicit type annotation workaround (should work)
func testExplicitTypeAnnotation() {
  var array: [Double] = [1.0, 2.0, 3.0]

  func asyncAfter(_ work: @escaping () -> Void) { work() }

  asyncAfter {
    withAnimation {
      let _: Double = array.remove(at: 0)
    }
  }
}

// Test case 5: Multiple generic parameters
func withAnimationAndCompletion<Result, Completion>(
  _ body: () throws -> Result,
  completion: (Result) -> Completion
) rethrows -> Completion {
  try completion(body())
}

func testMultipleGenericParams() {
  var array: [Int] = [10, 20, 30]

  func asyncAfter(_ work: @escaping () -> Void) { work() }

  asyncAfter {
    withAnimationAndCompletion({
      array.remove(at: 1)
    }, completion: { removed in
      print(removed)
    })
  }
}

// Test case 6: Generic closure returning the removed element
func testGenericClosureWithReturnValue() {
  var array: [Int] = [1, 2, 3]

  func asyncAfter(_ work: @escaping () -> Void) { work() }

  asyncAfter {
    let removed = withAnimation {
      array.remove(at: 0)
    }
    _ = removed
  }
}

// Test case 7: Protocol conforming type with both concrete and protocol methods
protocol CustomCollection: RangeReplaceableCollection {
  mutating func customRemove(at index: Index) -> Element
}

extension CustomCollection {
  mutating func customRemove(at index: Index) -> Element {
    return self.remove(at: index)
  }
}

struct ConcreteArray<T>: CustomCollection {
  typealias Index = Int
  typealias Element = T

  var storage: [T]

  var startIndex: Int { storage.startIndex }
  var endIndex: Int { storage.endIndex }

  init() { storage = [] }

  subscript(position: Int) -> T {
    get { storage[position] }
    set { storage[position] = newValue }
  }

  func index(after i: Int) -> Int { storage.index(after: i) }

  mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C)
    where C: Collection, T == C.Element {
    storage.replaceSubrange(subrange, with: newElements)
  }

  // Concrete implementation that should be preferred
  mutating func remove(at index: Int) -> T {
    return storage.remove(at: index)
  }
}

func testConcreteVsProtocolExtension() {
  var customArray = ConcreteArray<Double>()
  customArray.storage = [1.0, 2.0, 3.0]

  func asyncAfter(_ work: @escaping () -> Void) { work() }

  asyncAfter {
    withAnimation {
      // Should prefer ConcreteArray.remove(at:) over RangeReplaceableCollection.remove(at:)
      customArray.remove(at: 0)
    }
  }
}
