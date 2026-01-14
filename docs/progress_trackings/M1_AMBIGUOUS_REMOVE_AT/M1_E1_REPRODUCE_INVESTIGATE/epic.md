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

### Investigation Hierarchy (To Be Completed in I2)

| Level | Question | Finding |
|-------|----------|---------|
| 1. Symptom | What failed? | Pending I1 reproduction |
| 2. Trigger | What input/state caused it? | Pending |
| 3. Mechanism | How did code produce failure? | Pending |
| 4. Assumption | What assumption was violated? | Pending |
| 5. Origin | Where did assumption come from? | Pending |
| 6. Pattern | Recurring pattern in codebase? | Pending |
| 7. Prevention | How to prevent this class of bug? | Pending |

### Affected Code Paths (Known from prior exploration)

- `lib/Sema/CSRanking.cpp` - Overload ranking logic (~lines 546-588)
- `lib/Sema/CSGen.cpp` - Closure type inference (~lines 2640-2662)

## Iteration Breakdown

| Iteration | Focus | Status |
|-----------|-------|--------|
| I1: Reproduction | Build compiler, verify bug reproduces | in_progress |
| I2: Investigation | Apply 7-level investigation hierarchy | planned |
