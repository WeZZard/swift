---
iteration: I1
epic: E1
milestone: M1
slug: M1_E1_I1_REPRODUCTION
status: completed
work_item_type: issue
work_item_id: IS-0001
outcome: success
outcome_summary:
completed_date: 2026-01-15
---

# Iteration M1_E1_I1: Bug Reproduction

**Goal:** Verify the bug reproduces on current main branch and establish baseline environment.

## Steps

### 1. Verify Git State

- Confirm on `main` branch at current HEAD (355424f8b50 or later)
- No need to checkout specific version - testing on latest

### 2. Build Swift Compiler

```bash
cd /Users/wezzard/Projects/ada-build-test/swift-ada-build-test-1/swift
utils/build-script --skip-build-benchmarks \
  --swift-darwin-supported-archs "$(uname -m)" \
  --release-debuginfo --swift-disable-dead-stripping \
  --bootstrapping=hosttools
```

If build artifacts already exist, use incremental build:
```bash
platform=$([[ $(uname) == Darwin ]] && echo macosx || echo linux)
ninja -C ../build/Ninja-RelWithDebInfoAssert/swift-${platform}-$(uname -m) bin/swift-frontend
```

### 3. Create Reproduction Test

Create `test_ambiguous_remove.swift`:
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

### 4. Execute Reproduction

```bash
../build/Ninja-RelWithDebInfoAssert/swift-macosx-$(uname -m)/bin/swift-frontend \
  -typecheck test_ambiguous_remove.swift
```

### 5. Document Results

Record:
- Does the bug reproduce? (Yes/No)
- Exact error message and line numbers
- Any variations in behavior

### 6. Decision Gate

- **Bug reproduces:** Proceed to I2 for investigation
- **Bug does NOT reproduce:** Investigate why (environment issue? already fixed?)
- **Already fixed on main:** Document which commit fixed it, close issue

## Success Criteria

- Swift compiler builds successfully
- Reproduction test executed
- Bug status confirmed (reproduces / does not reproduce / already fixed)
- Decision documented for next iteration

## Verification

Run the reproduction test and capture output. Compare against expected error:
```
error: ambiguous use of 'remove(at:)'
note: found this candidate
note: found this candidate
```

## Roadmap

| Next | Focus |
|------|-------|
| I2 | Apply 7-level investigation hierarchy if bug reproduces |
