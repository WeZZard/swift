---
id: IS-0001
title: Ambiguous use of remove(at:) for Array.remove in nested generic closures
status: draft
severity: medium
author: builder
created: 2026-01-14
reviewed: null
fixed: null
planned_in: null
---

# IS-0001: Ambiguous use of remove(at:) for Array.remove in nested generic closures

## Summary

The Swift compiler incorrectly reports "ambiguous use of 'remove(at:)'" when calling `Array.remove(at:)` inside nested closures that combine `DispatchQueue.asyncAfter` with a generic function like `withAnimation<Result>`. The compiler claims two candidates exist (`Array.remove(at:)` and `RangeReplaceableCollection.remove(at:)`) even though there's only one actual implementation.

## Reproduction Steps

1. Create a Swift file with the following code:
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
2. Compile with `swiftc`
3. Observe the compiler error

## Expected Behavior

The code should compile successfully. `Array.remove(at:)` is the only implementation that should be selected since Array provides a specialized version of this method.

## Actual Behavior

Compiler reports: "ambiguous use of 'remove(at:)'" with two candidates:
- `Swift.Array.remove(at:)`
- `Swift.RangeReplaceableCollection.remove(at:)`

## Environment

- **OS:** Any (macOS, Linux)
- **Version:** Swift main branch (current HEAD: 355424f8b50)
- **Configuration:** Default

## Version Identification

- **Git reference:** `main` branch at commit `355424f8b50`
- **Release version:** Pre-release (development branch)
- **Known affected versions:** Likely affects Swift 5.x and 6.x releases

## Affected Components

- `lib/Sema/CSRanking.cpp` - Overload ranking logic
- `lib/Sema/CSGen.cpp` - Closure type inference

## Severity Assessment

**Severity:** medium

**Justification:**
This affects common patterns in SwiftUI development (combining animation closures with async dispatch). It produces confusing error messages for valid code.

**Impact:**

- SwiftUI developers using `withAnimation` + async patterns
- Workarounds exist but are non-obvious
- Does not cause crashes or data corruption

## Proposed Fix Approach

Two complementary fixes identified:

1. **Conservative Fix (CSRanking.cpp):** Add check after line 588 to prefer concrete nominal type members (Array) over protocol extension members (RangeReplaceableCollection) when constraint scores are equal. Use `getSelfNominalTypeDecl()` to compare.

2. **Root Cause Fix (CSGen.cpp):** In the closure result type inference around line 2650, check if the contextual result type contains unresolved type parameters from outer generic contexts. If so, don't use it as the contextual result type to prevent under-constrained type variables.

## Workaround

Users can work around this issue by:
1. Assigning the return value: `_ = opacities.remove(at: 2)`
2. Adding explicit return: `withAnimation { return opacities.remove(at: 2) }`
3. Adding additional statements in the closure

## Related Issues

- Swift Forums: https://forums.swift.org/t/ambiguous-use-of-remove-at-for-array-remove/83875
