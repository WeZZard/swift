---
id: IS-0001
title: Ambiguous use of 'remove(at:)' in nested closure contexts
status: draft
severity: medium
author: builder
created: 2026-01-14
reviewed: null
fixed: null
planned_in: null
---

# IS-0001: Ambiguous use of 'remove(at:)' in nested closure contexts

## Summary

The Swift compiler incorrectly reports "ambiguous use of 'remove(at:)'" when calling `Array.remove(at:)` inside nested closures (e.g., `withAnimation` inside `DispatchQueue.main.asyncAfter`). The compiler fails to disambiguate between candidates from `Array` and `RangeReplaceableCollection`, despite the existence of ranking logic that should prefer concrete type members over protocol members.

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
            opacities.remove(at: 2)
        }
    }
}
```
2. Compile the file with `swiftc`

## Expected Behavior

The code should compile successfully. The compiler should resolve `remove(at:)` to `Array.remove(at:)` without ambiguity, as the concrete type member should be preferred over the protocol default implementation.

## Actual Behavior

The compiler reports:
```
error: ambiguous use of 'remove(at:)'
            opacities.remove(at: 2)
                      ^
note: found this candidate
    public mutating func remove(at index: Int) -> Element
                         ^
note: found this candidate
    public mutating func remove(at position: Index) -> Element
                         ^
```

The two candidates are:
- `Array.remove(at:)` from `stdlib/public/core/Array.swift:1347`
- `RangeReplaceableCollection.remove(at:)` from `stdlib/public/core/RangeReplaceableCollection.swift:545`

## Environment

- **OS:** Any
- **Version:** Current main branch
- **Configuration:** Standard Swift compilation

## Version Identification

- **Git reference:** main branch (commit 355424f8b50)
- **Release version:** [TBD - needs verification on released versions]
- **Known affected versions:** [TBD]

## Affected Components

- `lib/Sema/CSRanking.cpp` - Solution ranking and disambiguation logic
- `lib/Sema/CSGen.cpp` - Closure type inference and constraint generation
- `lib/Sema/CSSimplify.cpp` - Constraint simplification for nested closures

## Severity Assessment

**Severity:** medium

**Justification:**
This affects common Swift patterns (closures inside animation blocks, async callbacks). The issue is reproducible and has no clean workaround. However, it doesn't cause crashes or data corruption.

**Impact:**

- Affects developers using nested closure patterns with collection mutations
- Occurs when combining generic function calls (like `withAnimation`, `asyncAfter`) with array operations
- Workaround exists but requires explicit type annotations

## Proposed Fix Approach

The root cause appears to be in how type constraints propagate through nested generic closures. Investigation points to:

1. **CSRanking.cpp lines 546-588**: Contains disambiguation logic that should prefer concrete type members over protocol members, but this logic may not be triggered correctly in nested closure contexts

2. **CSGen.cpp `inferClosureType()`**: The closure result type inference may not properly propagate contextual types through nested closure chains, leaving the inner closure's result type underconstrained

3. **FallbackType constraint mechanism**: The `TypeVarRefCollector` and `referencedVars` may not correctly connect nested closures when there's a chain of generic function calls

The fix likely involves ensuring proper contextual type propagation from outer generic functions down through nested closures, so that method overload resolution has sufficient type information to apply the disambiguation rules.

## Workaround

Add explicit type annotation to help the compiler resolve the ambiguity:
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    withAnimation {
        let _: Double = opacities.remove(at: 2)
    }
}
```

Or use explicit `as Array` cast on the receiver.

## Related Issues

- Forum discussion: https://forums.swift.org/t/ambiguous-use-of-remove-at-for-array-remove/83875
