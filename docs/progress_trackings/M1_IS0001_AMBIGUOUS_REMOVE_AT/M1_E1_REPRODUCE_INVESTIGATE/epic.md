---
epic: E1
milestone: M1
slug: M1_E1_REPRODUCE_INVESTIGATE
status: in_progress
outcome: null
outcome_summary: null
---

# Epic M1_E1: Reproduce and Investigate Root Cause

**Goal:** Confirm the bug reproduces on the current main branch and investigate the root cause using the 7-level investigation hierarchy.

## Investigation Approach

For this bug fix, we follow the IS-XXXX investigation hierarchy:

| Level | Question | Finding |
|-------|----------|---------|
| 1. Symptom | What failed? | Compiler reports "ambiguous use of 'remove(at:)'" for Array.remove(at:) in nested generic closures |
| 2. Trigger | What input/state caused it? | Nested generic closure (e.g., `withAnimation<Result>`) wrapping array mutation where result is discarded |
| 3. Mechanism | How did code produce failure? | Constraint solver produces 4 ambiguous solutions with identical scores. When withAnimation<Result> closure processes remove(at:), the generic parameter Result can be Void or Double equally. Both Array.remove and protocol extension remove have same constraint score. CSRanking returns "not better" because neither is definitively more specialized in nested generic context. |
| 4. Assumption | What assumption was violated? | getContextualType(forConstraint=false) assumes returned type is either concrete or will be properly constrained after replaceInferableTypesWithTypeVars. For nested generics, the type variable is created BEFORE body analysis establishes constraints. |
| 5. Origin | Where did assumption come from? | Design decision in CSGen.cpp lines 2644-2648: "we avoid prematurely converting any inferrable types by setting forConstraint=false". This doesn't account for outer generic functions with unresolved type parameters. |
| 6. Pattern | Recurring pattern in codebase? | Generic closure parameter inference with discarded return values. Affects any case where Array methods compete with RangeReplaceableCollection protocol extension methods in nested generic closures. |
| 7. Prevention | How to prevent this class of bug? | Fix in CSRanking.cpp to better prefer concrete Array.remove over protocol extension when scores are equal. OR root cause fix in CSGen.cpp to properly constrain Result type variable. |

**Levels 1-3** inform the conservative fix.
**Levels 4-7** inform the root cause fix.

## Affected Code Paths (Preliminary)

Based on issue documentation:
- `lib/Sema/CSRanking.cpp` - Solution ranking and disambiguation logic (lines 546-588)
- `lib/Sema/CSGen.cpp` - Closure type inference and constraint generation
- `lib/Sema/CSSimplify.cpp` - Constraint simplification for nested closures

## Iteration Breakdown

| Iteration | Goal | Status |
|-----------|------|--------|
| I1: Reproduction | Reproduce bug, confirm it exists on main | completed |
| I2: Investigation | Complete 7-level hierarchy, identify fix approach | completed |
| I3: Implementation | Implement conservative and root cause fixes | planned |

## Recommended Fix Approaches for I3

Based on the investigation findings:

1. **Conservative Fix:** Improve CSRanking.cpp line 558-561 to properly prefer Array.remove over RangeReplaceableCollection.remove even when constraint scores are equal
2. **Root Cause Fix:** Modify inferClosureType in CSGen.cpp to detect unresolved generic parameters from outer contexts and establish proper constraints
