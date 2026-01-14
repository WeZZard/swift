---
iteration: I1
epic: E1
milestone: M1
slug: M1_E1_I1_REPRODUCTION
status: completed
work_item_type: issue
work_item_id: IS-0001
outcome: success
outcome_summary: null
completed_date: 2026-01-14
---

# Iteration M1_E1_I1: Bug Reproduction

**Goal:** Reproduce the bug on the current main branch and confirm it still exists. No fixes, no root cause claims.

## What I1 Must Produce

1. Confirmed reproduction (or documented failure to reproduce)
2. Environment verification (Swift version, build configuration)
3. Comparison: behavior on main vs expected behavior
4. Decision: proceed to I2 for investigation or close if already fixed

## What I1 Must NOT Do

- Claim root cause without reproduction
- Propose code fixes
- Make code changes
- Jump to investigation levels 4-7

## Reproduction Plan

### Step 1: Build Swift Compiler

Build the Swift compiler with debug info for investigation:

```bash
utils/build-script --skip-build-benchmarks \
  --swift-darwin-supported-archs "$(uname -m)" \
  --release-debuginfo \
  --bootstrapping=hosttools
```

Build output location: `../build/Ninja-RelWithDebInfoAssert/swift-macosx-arm64/`

### Step 2: Create Minimal Test Case

Create `test_is0001_remove_at.swift` with the reproduction case from the issue:

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

### Step 3: Run Compiler and Capture Output

```bash
../build/Ninja-RelWithDebInfoAssert/swift-macosx-arm64/bin/swift-frontend \
  -typecheck test_is0001_remove_at.swift 2>&1
```

Expected error (if bug reproduces):
```
error: ambiguous use of 'remove(at:)'
```

### Step 4: Test Variations

Test simplified cases to narrow the trigger:

1. Single closure (no nesting) - should work
2. Nested closures without generics - should work
3. Nested generic closures - should fail (the bug)

### Step 5: Document Findings

Record in iteration outcome:
- Exact compiler version/commit
- Full error output with notes
- Which variations trigger vs don't trigger the bug
- Any relevant compiler flags that affect behavior

## Verification Checklist

- [ ] Swift compiler builds successfully
- [ ] Test case created and matches issue description
- [ ] Bug reproduces with expected error message
- [ ] Variations tested to confirm trigger conditions
- [ ] Findings documented in iteration outcome

## Decision Gate

After I1:
- **Bug reproduces:** Proceed to I2 for investigation (levels 1-7)
- **Bug does NOT reproduce:** Investigate if already fixed, document which commit fixed it
- **Unclear reproduction:** Ask user for clarification on reproduction steps

## Roadmap

| Next | Focus |
|------|-------|
| I2 | Complete 7-level investigation hierarchy, identify fix approach |
| I3 | Implement conservative fix and root cause fix with tests |
