---
milestone: M1
slug: M1_AMBIGUOUS_REMOVE_AT
status: completed
outcome: success
outcome_summary: Conservative fix implemented in CSRanking.cpp to prefer concrete type members over protocol extension members when scores are equal. Regression test added.
artifact_type: issue
artifact_id: IS-0001
---

# Milestone M1: Fix Ambiguous remove(at:) in Nested Generic Closures

**Goal:** Resolve the spurious "ambiguous use of 'remove(at:)'" compiler error when calling Array.remove(at:) inside nested generic closures.

### Problem Statement

The Swift compiler incorrectly reports "ambiguous use of 'remove(at:)'" when calling `Array.remove(at:)` inside nested closures that combine:
1. `DispatchQueue.asyncAfter` (or similar async dispatch)
2. A generic function like `withAnimation<Result>`
3. A single-expression closure calling `remove(at:)`

The compiler claims two candidates exist (`Array.remove(at:)` and `RangeReplaceableCollection.remove(at:)`) even though Array's implementation should be preferred.

### Version Identification

- **Git reference:** `main` branch at commit `355424f8b50`
- **Known affected versions:** Current main, likely affects Swift 5.x and 6.x releases

### Environment Details

- **Operating system:** macOS (arm64 or x86_64), Linux
- **Dependencies:** Standard Swift toolchain build dependencies
- **Configuration:** Default build configuration

### Reproduction Steps

1. Create a Swift file with:
   ```swift
   import Dispatch

   func withAnimation<Result>(_ body: () throws -> Result) rethrows -> Result {
       try body()
   }

   func test() {
       var opacities: [Double] = [0, 0.5, 1.0]
       DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
           withAnimation {
               opacities.remove(at: 2) // Error occurs here
           }
       }
   }
   ```
2. Compile with `swiftc` or `swift-frontend -typecheck`
3. Observe compiler error

**Expected behavior:** Code compiles successfully
**Actual behavior:** "ambiguous use of 'remove(at:)'" error

### Impact Assessment

- **Severity:** Medium
- **Affected users/systems:** SwiftUI developers using animation + async patterns
- **Workaround available:** Yes - assign return value (`_ = opacities.remove(at: 2)`)
- **Data impact:** None

### Conservative Fix Goal

Make the specific failing pattern compile by ensuring concrete type members (Array) are preferred over protocol extension members (RangeReplaceableCollection) when scores are equal.

### Root Cause Fix Goal

Prevent under-constrained closure result types from outer generic contexts from causing spurious ambiguity.

## Epic Breakdown

| Epic | Focus | Status |
|------|-------|--------|
| E1: Reproduce & Investigate | Confirm bug, investigate mechanism, implement conservative fix | completed |
| E2: Root Cause Fix | Improve closure inference (optional, deferred) | skipped |
