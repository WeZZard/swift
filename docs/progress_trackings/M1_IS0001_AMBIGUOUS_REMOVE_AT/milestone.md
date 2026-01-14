---
milestone: M1
slug: M1_IS0001_AMBIGUOUS_REMOVE_AT
status: in_progress
artifact_type: issue
artifact_id: IS-0001
---

# Milestone M1: Resolve Ambiguous remove(at:) in Nested Closures

**Goal:** Fix Swift compiler bug where Array.remove(at:) is incorrectly reported as ambiguous when called inside nested closure contexts.

## Problem Statement

The Swift compiler fails to disambiguate between:
- `Array.remove(at: Int) -> Element` (concrete type method)
- `RangeReplaceableCollection.remove(at: Index) -> Element` (protocol default)

This occurs specifically in nested closure contexts (e.g., `asyncAfter { withAnimation { array.remove(at:) } }`).

### Version Identification

- **Git reference:** main branch (commit 355424f8b50)
- **Release version:** TBD - needs verification on released versions
- **Known affected versions:** TBD

### Environment Details

- **Operating system:** Any (reported on macOS, likely affects all platforms)
- **Dependencies:** Standard Swift compilation, Dispatch framework for reproduction
- **Configuration:** Standard Swift compilation settings
- **Required state:** None - reproduces with fresh compilation

### Reproduction Steps

1. Create a Swift file with nested closures calling `Array.remove(at:)`:
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
2. Compile the file with `swiftc` or `swift-frontend -typecheck`

**Expected behavior:** Code compiles successfully, resolving to `Array.remove(at:)`
**Actual behavior:** Compiler reports "ambiguous use of 'remove(at:)'"
**Error output:**
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

### Impact Assessment

- **Severity:** Medium
- **Affected users/systems:** Developers using nested closure patterns with collection mutations
- **Workaround available:** Yes - add explicit type annotation: `let _: Double = opacities.remove(at: 2)`
- **Data impact:** None - compilation error only

### Success Criteria

1. **Conservative fix:** The specific reproduction case compiles without ambiguity error
2. **Root cause fix:** The disambiguation logic correctly prefers concrete type members in all nested closure contexts
3. **Regression test:** Test added to prevent recurrence
4. **Root cause test:** Test validates the invariant that should hold

## Epic Breakdown

| Epic | Goal | Status |
|------|------|--------|
| E1: Reproduce and Investigate | Confirm bug reproduces, investigate root cause using 7-level hierarchy | in_progress |
