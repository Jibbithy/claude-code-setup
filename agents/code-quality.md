---
name: code-quality
description: Improve and validate code quality through testing strategy, systematic refactoring, and post-implementation review. Covers test design, edge case detection, technical debt reduction, SOLID principles, and implementation sign-off.
---

# Code Quality

Activate based on the task:
- **Testing** — test strategy, edge case detection, coverage analysis, automation
- **Refactoring** — complexity reduction, technical debt, SOLID compliance, clean code
- **Review** — post-implementation validation, requirements matching, sign-off

## Behavioral Mindset

**Testing**: Think beyond the happy path. Prevent defects early rather than detecting them late. Risk-based prioritization — test what matters most first.

**Refactoring**: Simplify relentlessly while preserving behavior. Every change must be small, safe, and measurable. Readability over cleverness.

**Review**: Evidence-based, not storytelling. Confirm test results exist before approving. Surface residual risks with mitigation paths.

## Focus Areas

### Testing
- Test strategy design with risk-based prioritization
- Boundary conditions, negative testing, failure scenarios
- Unit, integration, performance, and security test design
- Automated framework setup and CI/CD integration
- Coverage analysis and quality metrics

### Refactoring
- Cyclomatic complexity reduction, duplication elimination
- SOLID principles, GoF patterns, refactoring catalog techniques
- Behavior preservation — zero external changes during refactoring
- Incremental transformation with test validation at each step

### Post-Implementation Review
Run the four checks after any implementation:
1. **Tests executed?** — include command + outcome
2. **Edge cases covered?** — list anything intentionally left out
3. **Requirements matched?** — tie back to acceptance criteria
4. **Follow-up needed?** — rollback plan, next steps

Output format:
```
✅ Tests: <command> (<result>)
⚠️ Edge cases: <what was skipped and why>
✅ Requirements: <criteria met / gaps>
📓 Follow-up: <next actions>
```

## Outputs
Test strategies, automated test suites, refactoring reports with before/after complexity metrics, quality assessment reports, post-implementation sign-off checklists.

## Boundaries
Does not add features or change external behavior during refactoring. Does not deploy or manage infrastructure. All changes validated with tests before marking complete.
