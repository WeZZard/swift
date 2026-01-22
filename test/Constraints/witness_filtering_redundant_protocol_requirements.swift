// RUN: %target-typecheck-verify-swift

// Test for the witness-based filtering of redundant protocol requirements.
// When a concrete member IS the witness for a protocol requirement, the
// protocol requirement should be filtered out to avoid spurious ambiguity.

// =============================================================================
// Basic case: Array.remove(at:) vs RangeReplaceableCollection.remove(at:)
// =============================================================================

func testArrayRemove() {
  var arr = [1, 2, 3]
  // Array.remove(at:) IS the witness for RRC.remove(at:), so the protocol
  // requirement should be filtered out. This should compile without ambiguity.
  arr.remove(at: 0)
  _ = arr.remove(at: 0)
}

// =============================================================================
// Generic context: T where T: RangeReplaceableCollection
// =============================================================================

func testGenericRemove<T: RangeReplaceableCollection>(_ collection: inout T) where T.Index == Int {
  // In a generic context, the concrete witness is not available.
  // The protocol requirement should remain as the only candidate.
  collection.remove(at: 0)
}

// =============================================================================
// Protocol extension methods
// =============================================================================

protocol HasDefaultImpl {
  func foo() -> Int
}

extension HasDefaultImpl {
  func foo() -> Int { return 0 }
}

struct ConcreteImpl: HasDefaultImpl {
  // This IS the witness for HasDefaultImpl.foo()
  func foo() -> Int { return 42 }
}

func testProtocolExtensionVsConcrete() {
  let impl = ConcreteImpl()
  // Should resolve to ConcreteImpl.foo() without ambiguity
  _ = impl.foo()
}

// =============================================================================
// Existential types: Protocol requirements MUST be kept
// =============================================================================

func testExistentialType() {
  let existential: any HasDefaultImpl = ConcreteImpl()
  // On existential types, we must keep the protocol requirement
  // because we're calling through the protocol witness table
  _ = existential.foo()
}

// =============================================================================
// Multiple conformances with same witness
// =============================================================================

protocol P1 {
  func bar()
}

protocol P2 {
  func bar()
}

struct MultiConformer: P1, P2 {
  // This single method witnesses both P1.bar() and P2.bar()
  func bar() {}
}

func testMultipleConformances() {
  let m = MultiConformer()
  // Should resolve without ambiguity
  m.bar()
}

// =============================================================================
// Inherited protocol requirements
// =============================================================================

protocol Base {
  func baz() -> Int
}

protocol Derived: Base {}

struct DerivedImpl: Derived {
  func baz() -> Int { return 1 }
}

func testInheritedRequirement() {
  let d = DerivedImpl()
  // The concrete method witnesses Base.baz() through Derived
  _ = d.baz()
}

// =============================================================================
// Method chaining with discardable result
// =============================================================================

func testMethodChaining() {
  var arr = [1, 2, 3, 4, 5]
  // Test that @discardableResult works correctly with filtering
  arr.remove(at: 0)
  let removed = arr.remove(at: 0)
  _ = removed
}

// =============================================================================
// Subscript requirements
// =============================================================================

func testSubscriptRequirement() {
  var arr = [1, 2, 3]
  // Array subscript IS the witness for Collection subscript requirement
  _ = arr[0]
  arr[0] = 42
}

// =============================================================================
// Associated type requirements
// =============================================================================

protocol HasAssociatedType {
  associatedtype Element
  func getElement() -> Element
}

struct ConcreteElement: HasAssociatedType {
  typealias Element = Int
  func getElement() -> Int { return 0 }
}

func testAssociatedTypeRequirement() {
  let c = ConcreteElement()
  let _: Int = c.getElement()
}
