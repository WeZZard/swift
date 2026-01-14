---
iteration: I3
epic: E1
milestone: M1
slug: M1_E1_I3_IMPLEMENTATION
status: completed
work_item_type: issue
work_item_id: IS-0001
outcome: success
outcome_summary:
completed_date: 2026-01-15
---

# Iteration M1_E1_I3: Implementation

**Goal:** Implement the conservative fix to resolve the "ambiguous use of 'remove(at:)'" compiler error in nested generic closures, and add a regression test.

## Approach

Based on the I2 investigation findings, this iteration implements:

1. **Conservative Fix** (Primary)
   - Location: `lib/Sema/CSRanking.cpp` in `compareSolutions()` around line 1580-1590
   - Add a tie-breaker that prefers concrete type members over protocol extension members when scores are equal
   - This mirrors the existing logic in `isDeclAsSpecializedAs()` but applies at the solution comparison level

2. **Regression Test**
   - Add a test case that reproduces the bug scenario
   - Test should pass after the fix and fail if the bug regresses

3. **Root Cause Fix** (Deferred to future iteration if needed)
   - The root cause fix involves improving closure result type inference in CSGen.cpp
   - This is a larger scope change and may be addressed in a follow-up iteration

## Implementation Steps

### Step 1: Create Fix Branch

```bash
git checkout -b bugfix/issue-0001-conservative-fix
```

### Step 2: Implement Conservative Fix

In `lib/Sema/CSRanking.cpp`, locate `compareSolutions()` (around line 1053-1633) and add a tie-breaker after the existing comparison logic (around line 1580-1590) that:

1. Checks if both solutions have equal fixed scores
2. For each overload choice, compares if one is from a concrete type and the other from a protocol extension
3. Prefers the concrete type member using `getSelfNominalTypeDecl()` to distinguish

### Step 3: Add Regression Test

Create test file in `test/Constraints/` that covers:

```swift
// RUN: %target-typecheck-verify-swift

import Dispatch

func withAnimation<Result>(_ body: () throws -> Result) rethrows -> Result {
    try body()
}

func test() {
    var opacities: [Double] = [0, 0.5, 1.0]
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        withAnimation {
            opacities.remove(at: 2) // should compile without ambiguity error
        }
    }
}
```

### Step 4: Build and Validate

```bash
# Build the compiler
ninja -C ../build/Ninja-RelWithDebInfoAssert/swift-macosx-$(uname -m) bin/swift-frontend

# Run the reproduction test
../build/Ninja-RelWithDebInfoAssert/swift-macosx-$(uname -m)/bin/swift-frontend \
  -typecheck test_ambiguous_remove.swift

# Run the new regression test
../build/Ninja-RelWithDebInfoAssert/swift-macosx-$(uname -m)/bin/llvm-lit \
  -sv test/Constraints/nested_closure_overload_ranking.swift
```

### Step 5: Verify No Regressions

Run the full constraint solver test suite:

```bash
../build/Ninja-RelWithDebInfoAssert/swift-macosx-$(uname -m)/bin/llvm-lit \
  -sv test/Constraints/
```

## Success Criteria

- [ ] Conservative fix implemented in CSRanking.cpp
- [ ] Build passes
- [ ] Original reproduction case compiles without error
- [ ] Regression test added and passes
- [ ] No regressions in existing constraint solver tests

## Affected Code Paths

- `lib/Sema/CSRanking.cpp:compareSolutions()` - Primary fix location
- `test/Constraints/` - New regression test

## Roadmap

| Next | Focus |
|------|-------|
| I4 (if needed) | Root cause fix in CSGen.cpp closure inference |
