---
iteration: I2
epic: E1
milestone: M1
slug: M1_E1_I2_INVESTIGATION
status: completed
work_item_type: issue
work_item_id: IS-0001
outcome: success
outcome_summary:
completed_date: 2026-01-15
---

# Iteration M1_E1_I2: Investigation

**Goal:** Apply the full 7-level investigation hierarchy to understand the bug mechanism and identify fix approaches.

## Investigation Scope

This iteration performs **investigation only** - no code changes.

Output: Update epic.md with complete investigation findings at all 7 levels.

## Investigation Steps

### Level 1: Symptom (What failed?)

Document the exact failure:
- Error message: "ambiguous use of 'remove(at:)'"
- Two candidates reported: `Array.remove(at:)` and `RangeReplaceableCollection.remove(at:)`
- Location: Line calling `opacities.remove(at: 2)` inside nested closures

### Level 2: Trigger (What input/state caused it?)

Identify the triggering pattern:
- `DispatchQueue.main.asyncAfter` wrapping closure
- Generic function `withAnimation<Result>` wrapping closure
- Single-expression closure body calling `remove(at:)`
- Return type of `remove(at:)` is `Element` (Double in this case)

### Level 3: Mechanism (How did code produce failure?)

Trace through constraint solver:
1. Explore `lib/Sema/CSRanking.cpp` overload ranking logic
2. Explore `lib/Sema/CSGen.cpp` closure type inference
3. Identify where ambiguity is detected
4. Trace why two candidates have equal scores

### Level 4: Assumption (What assumption was violated?)

Identify the violated assumption:
- Expected: Concrete type member (Array) preferred over protocol extension member
- Actual: Both have equal constraint scores in nested generic context

### Level 5: Origin (Where did assumption come from?)

Trace the origin:
- Protocol extension vs concrete type ranking logic in CSRanking.cpp
- Closure result type inference in CSGen.cpp
- Generic parameter inference in nested contexts

### Level 6: Pattern (Recurring pattern in codebase?)

Search for similar issues:
- Other collection methods that might have same issue
- Other protocol/concrete type disambiguation scenarios
- Existing tests for similar patterns

### Level 7: Prevention (What would prevent this class of bug?)

Identify prevention strategy:
- Conservative fix approach
- Root cause fix approach
- Test coverage additions

## Deliverables

1. **Update epic.md** with complete investigation findings table
2. **Document fix approaches** (conservative + root cause)
3. **Identify affected code paths** with line numbers
4. **No code changes** - investigation only

## Success Criteria

- All 7 investigation levels documented
- Conservative fix approach identified
- Root cause fix approach identified
- Ready to proceed to I3 (Implementation)

## Roadmap

| Next | Focus |
|------|-------|
| I3 | Implement conservative fix + root cause fix |
