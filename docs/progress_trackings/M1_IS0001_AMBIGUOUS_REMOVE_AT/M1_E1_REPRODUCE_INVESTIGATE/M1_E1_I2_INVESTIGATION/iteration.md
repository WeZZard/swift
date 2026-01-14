---
iteration: I2
epic: E1
milestone: M1
slug: M1_E1_I2_INVESTIGATION
status: completed
work_item_type: issue
work_item_id: IS-0001
outcome: success
outcome_summary: Completed 7-level investigation hierarchy; identified root cause in CSGen.cpp contextual type handling and recommended both conservative (CSRanking.cpp) and root cause (CSGen.cpp) fix approaches for I3
completed_date: 2026-01-14
---

# Iteration M1_E1_I2: Root Cause Investigation

**Goal:** Complete the 7-level investigation hierarchy to identify the root cause of the disambiguation failure, and determine the fix approach for I3.

## Context from I1

Bug IS-0001 was successfully reproduced in I1:
- **Symptom:** Compiler reports "ambiguous use of 'remove(at:)'" for `Array.remove(at:)` in nested generic closures
- **Trigger conditions identified:**
  - Array variable captured by outer closure
  - Inner closure is generic (return type inferred from body)
  - `remove(at:)` called with result discarded
  - The generic parameter `Result` in `withAnimation<Result>` creates the issue

## Investigation Hierarchy

This iteration completes levels 3-7 of the investigation:

| Level | Question | To Investigate |
|-------|----------|----------------|
| 3. Mechanism | How did the code produce this failure? | Trace constraint solver with `-debug-constraints` |
| 4. Assumption | What assumption was violated? | Why disambiguation logic doesn't trigger |
| 5. Origin | Where did that assumption come from? | Design of CSRanking concrete-vs-protocol logic |
| 6. Pattern | Is this a recurring pattern? | Search for similar issues in Swift bug tracker |
| 7. Prevention | What would prevent this class of failures? | Design fix approach |

## Investigation Plan

### Step 1: Capture Constraint Solver Debug Output

Run the failing test case with debug flags:

```bash
swiftc -Xfrontend -debug-constraints-on-line 12 test_is0001_variation3_nested_generic.swift 2>&1 > debug_output.txt
```

Capture:
- Type variables created for the inner closure
- Overload candidates for `remove(at:)`
- Solution scoring and comparison
- Why disambiguation fails

### Step 2: Trace the Ranking Logic

Based on exploration findings, the issue is likely in one of:

1. **CSRanking.cpp lines 583-588** - The concrete-vs-protocol check:
   ```cpp
   auto inProto1 = isa<ProtocolDecl>(outerDC1);
   auto inProto2 = isa<ProtocolDecl>(outerDC2);
   if (inProto1 != inProto2)
     return completeResult(inProto2);
   ```
   This checks if the **declaration context** is a protocol, not if the method is from a protocol. Both `Array.remove(at:)` and `RangeReplaceableCollection.remove(at:)` might appear as NOT being in protocol contexts when viewed from the generic closure.

2. **CSRanking.cpp lines 626-631** - Type environment mapping:
   ```cpp
   if (auto mapped = innerDC1->mapTypeIntoEnvironment(replacement.first)) {
     cs.addConstraint(ConstraintKind::Bind, replacement.second, mapped, locator);
   }
   ```
   If `mapTypeIntoEnvironment` returns null (no mapping available), no binding constraint is added.

3. **CSGen.cpp lines 2649-2652** - Contextual type retrieval:
   ```cpp
   if (auto contextualType = CS.getContextualType(closure, /*forConstraint=*/false)) {
     if (auto fnType = contextualType->getAs<FunctionType>())
       return fnType->getResult();
   }
   ```
   In nested generic closures, contextual type may not be available or may contain unresolved type variables.

### Step 3: Identify Root Cause

From the exploration, the most likely root cause is:

**When the inner closure in `withAnimation<Result> { ... }` is processed:**
1. The generic parameter `Result` is still a type variable
2. `getContextualType()` returns a type containing this unresolved type variable
3. The closure's result type becomes under-constrained
4. Without a known result type, both overloads have identical signatures: `(Int) -> Double`
5. The ranking logic at lines 583-588 doesn't help because it checks declaration context (not protocol membership)
6. Result: ambiguity

### Step 4: Document Fix Approach

Based on investigation, determine whether the fix should be:

1. **Conservative fix (I3):** Add special handling for this specific case
2. **Root cause fix (I3):** Improve contextual type propagation for nested generic closures
3. **Both:** Implement conservative fix first, then root cause fix

### Step 5: Update Epic Investigation Findings

Update `epic.md` with completed 7-level hierarchy findings.

## Key Files to Examine

| File | Lines | Purpose |
|------|-------|---------|
| `lib/Sema/CSRanking.cpp` | 546-588 | Disambiguation logic |
| `lib/Sema/CSRanking.cpp` | 626-631 | Type environment mapping |
| `lib/Sema/CSGen.cpp` | 2649-2652 | Contextual type retrieval |
| `lib/Sema/CSGen.cpp` | 2519-2692 | `inferClosureType()` |
| `lib/Sema/CSGen.cpp` | 3195-3223 | `visitClosureExpr()` |

## Debug Commands

```bash
# Full constraint debug for failing case
swiftc -Xfrontend -debug-constraints test_is0001_variation3_nested_generic.swift 2>&1 | head -500

# Line-specific debug
swiftc -Xfrontend -debug-constraints-on-line 8 test_is0001_variation3_nested_generic.swift

# Compare with working case
swiftc -Xfrontend -debug-constraints test_is0001_variation1_single_closure.swift 2>&1 | head -500
```

## Verification Checklist

- [x] Constraint solver debug output captured for failing case
- [x] Constraint solver debug output captured for working case (comparison)
- [x] Mechanism (level 3) documented: exactly how the failure occurs
- [x] Assumption (level 4) documented: what invariant is violated
- [x] Origin (level 5) documented: design decision that led to this
- [x] Pattern (level 6) documented: is this a known class of issues
- [x] Prevention (level 7) documented: recommended fix approach
- [x] Epic.md updated with investigation findings
- [x] Fix approach documented for I3

## Decision Gate

After I2:
- **Root cause identified:** Proceed to I3 for implementation
- **Root cause unclear:** Additional investigation iteration needed
- **Fix approach requires discussion:** Document options for human review

## Roadmap

| Next | Focus |
|------|-------|
| I3 | Implement conservative fix and root cause fix with tests |
