---
iteration: I3
epic: E1
milestone: M1
slug: M1_E1_I3_IMPLEMENTATION
status: completed
work_item_type: issue
work_item_id: IS-0001
outcome: success
outcome_summary: null
completed_date: 2026-01-14
---

# Iteration M1_E1_I3: Implement Conservative and Root Cause Fixes

**Goal:** Implement both the conservative fix and root cause fix for IS-0001, with comprehensive regression and root cause tests.

## Context from I2

The investigation identified:

1. **Mechanism**: Constraint solver produces 4 ambiguous solutions when the generic parameter `Result` in `withAnimation<Result>` can be Void or Double with equal scores
2. **Root Cause**: `getContextualType(closure, forConstraint=false)` in CSGen.cpp returns unresolved generic parameters that become under-constrained type variables
3. **Two Fix Approaches**:
   - Conservative: CSRanking.cpp lines 558-561
   - Root Cause: CSGen.cpp lines 2649-2652

## Implementation Plan

### Part 1: Conservative Fix (CSRanking.cpp)

**Location**: `lib/Sema/CSRanking.cpp` lines 558-561

**Current behavior**: The protocol extension check at lines 546-562 uses `getExtendedProtocolDecl()` which should prefer concrete type extensions over protocol extensions, but the disambiguation fails when both overloads have equal constraint scores.

**Fix approach**: Improve the disambiguation logic to properly detect when one declaration is a concrete type member (Array.remove) and the other is a protocol extension default implementation (RangeReplaceableCollection.remove), ensuring the concrete type is preferred even when constraint scores are equal.

**Key insight from investigation**: The check at lines 583-588 uses `isa<ProtocolDecl>(outerDC)` which only identifies declarations IN protocols, not protocol extension members. Need to ensure the earlier check at lines 558-561 handles this case correctly.

### Part 2: Root Cause Fix (CSGen.cpp)

**Location**: `lib/Sema/CSGen.cpp` lines 2644-2652

**Current behavior**: `getContextualType(closure, forConstraint=false)` returns unresolved generic parameters from outer functions. When `replaceInferableTypesWithTypeVars` converts these to type variables (line 2690), the conversion happens BEFORE the closure body is analyzed, leaving the result type under-constrained.

**Fix approach**: Detect when the contextual type contains unresolved generic parameters from outer contexts. In such cases, either:
- Don't use the contextual type; create a fresh type variable and let it be inferred from the body
- Or establish proper constraints between the outer generic parameter and the inner closure's result type variable

### Part 3: Regression Tests

Create test cases that verify the specific bug is fixed:

1. **test_nested_generic_closure_remove.swift**: The original failing case
2. **test_nested_generic_closure_variations.swift**: Additional variations to ensure comprehensive coverage

### Part 4: Root Cause Tests

Create tests that validate the invariant:

1. **test_contextual_type_propagation.swift**: Verify that contextual types with unresolved generics are handled correctly
2. **test_overload_ranking_concrete_vs_protocol.swift**: Verify concrete type methods are preferred over protocol extension defaults

## Files to Modify

| File | Lines | Change |
|------|-------|--------|
| `lib/Sema/CSRanking.cpp` | 546-588 | Conservative fix: improve disambiguation logic |
| `lib/Sema/CSGen.cpp` | 2644-2662 | Root cause fix: handle unresolved generics in contextual type |
| `test/Sema/overload_ranking_*.swift` | new | Regression and root cause tests |

## Verification Criteria

- [ ] Original reproduction case compiles without error
- [ ] All test variations (1-4) behave correctly
- [ ] Workaround (explicit type annotation) still works
- [ ] No regressions in existing Swift test suite
- [ ] Conservative fix alone resolves the specific issue
- [ ] Root cause fix prevents the class of issues

## Test Commands

```bash
# Verify fix works on original case
swiftc -typecheck test_is0001_variation3_nested_generic.swift

# Run new regression tests
./utils/run-test --filter overload_ranking

# Run full test suite to check for regressions
./utils/build-script --test
```

## Roadmap

| Next | Focus |
|------|-------|
| E2 | If needed: Additional optimization or edge case handling |
