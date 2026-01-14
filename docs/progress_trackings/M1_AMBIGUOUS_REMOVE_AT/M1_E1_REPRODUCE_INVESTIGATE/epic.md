---
epic: E1
milestone: M1
slug: M1_E1_REPRODUCE_INVESTIGATE
status: in_progress
outcome:
outcome_summary:
---

# Epic M1_E1: Reproduce and Investigate

**Goal:** Confirm the bug reproduces on current main branch and understand the failure mechanism.

### Scope

This epic covers:
1. Bug reproduction verification
2. Investigation of the failure mechanism (levels 1-7)

Fixes will be implemented in E2.

### Investigation Hierarchy (Completed in I2)

| Level | Question | Finding |
|-------|----------|---------|
| 1. Symptom | What failed? | Compiler error: "ambiguous use of 'remove(at:)'" with two candidates: `Array.remove(at:)` and `RangeReplaceableCollection.remove(at:)` |
| 2. Trigger | What input/state caused it? | Nested closures: `DispatchQueue.main.asyncAfter` + generic function `withAnimation<Result>` + single-expression closure calling `remove(at:)` |
| 3. Mechanism | How did code produce failure? | In nested generic contexts, closure result type becomes an under-constrained type variable (`TVO_CanBindToHole`). The `compareSolutions()` function in CSRanking.cpp compares overloads via `isDeclAsSpecializedAs()`, but both solutions appear equal because the type variable prevents proper disambiguation. |
| 4. Assumption | What assumption was violated? | Expected: Concrete type member (Array) always preferred over protocol extension member (RangeReplaceableCollection) via CSRanking.cpp:558-561. Actual: Both have equal constraint scores because outer generic context (`withAnimation<Result>`) creates under-constrained result type. |
| 5. Origin | Where did assumption come from? | The ranking logic at CSRanking.cpp:558-561 correctly prefers concrete types over protocol extensions when called from `isDeclAsSpecializedAs()`. However, the issue is that both overloads generate valid solutions with equal fixed scores before this comparison is reached, because the closure result type is a type variable that can bind to either `Double` (Array's Element) or `Self.Element` (RangeReplaceableCollection's associated type). |
| 6. Pattern | Recurring pattern in codebase? | Similar issues may affect other RangeReplaceableCollection methods: `removeFirst()`, `removeLast()`, `popFirst()`, `popLast()`. Any protocol extension method with a return type that matches a concrete type's implementation could exhibit this in nested generic contexts. See test/Sema/fixed_ambiguities/rdar36333688.swift for related protocol extension ranking tests. |
| 7. Prevention | How to prevent this class of bug? | Two fix approaches identified: (1) Conservative fix: Ensure concrete type preference is applied even when scores are equal in `compareSolutions()`. (2) Root cause fix: Improve closure result type inference in nested generic contexts to avoid creating under-constrained type variables when the enclosing context already has sufficient type information. |

### Affected Code Paths

**Primary:**
- `lib/Sema/CSRanking.cpp:558-561` - Protocol extension vs concrete type ranking (works correctly in isolation)
- `lib/Sema/CSRanking.cpp:1252-1262` - `isDeclAsSpecializedAs()` calls in `compareSolutions()`
- `lib/Sema/CSRanking.cpp:1598-1631` - Final score comparison and ambiguity detection

**Secondary:**
- `lib/Sema/CSGen.cpp:2655-2662` - Closure result type creation as type variable with `TVO_CanBindToHole`
- `lib/Sema/CSGen.cpp:2649-2653` - Contextual type extraction for closure result

### Fix Approaches

**Conservative Fix (Recommended for I3):**
Location: `lib/Sema/CSRanking.cpp` in `compareSolutions()` around line 1580-1590

Add a tie-breaker that prefers concrete type members over protocol extension members when scores are equal. This mirrors the existing logic in `isDeclAsSpecializedAs()` but applies at the solution comparison level.

**Root Cause Fix (Optional for I3 or future work):**
Location: `lib/Sema/CSGen.cpp` closure inference

Improve closure result type inference to propagate constraints from outer generic contexts more aggressively, preventing the creation of under-constrained type variables when sufficient type information exists.

## Iteration Breakdown

| Iteration | Focus | Status |
|-----------|-------|--------|
| I1: Reproduction | Build compiler, verify bug reproduces | completed |
| I2: Investigation | Apply 7-level investigation hierarchy | completed |
| I3: Implementation | Implement conservative fix + regression test | completed |
