<!--
Sync Impact Report
- Version change: (template, unversioned) -> 1.0.0
- Modified principles: none (initial ratification)
- Added sections:
  - Core Principles: I. Test-First (NON-NEGOTIABLE), II. Verification Before Done,
    III. Simplicity and Minimal Change
  - Development Workflow
  - Quality Gates
  - Governance
- Removed sections: template placeholder slots PRINCIPLE_4 and PRINCIPLE_5 (not defined;
  user input supplied a single governing principle, remaining principles derived from
  the project's working rules)
- Templates requiring updates: none checked (dependent templates read this file at runtime)
- Follow-up TODOs: none
-->

# Grabby Constitution

## Core Principles

### I. Test-First (NON-NEGOTIABLE)

Tests are written before the code they exercise. For every change, the sequence MUST be:

1. Write the tests that describe the intended behavior.
2. Run them and observe them fail for the expected reason.
3. Write the implementation.
4. Run the tests again and observe them pass.

A task is complete when, and only when, all of its tests pass. A task with any failing
test is not done, regardless of how much implementation exists. For a bug, the first step
MUST be a test that reproduces the bug; the fix follows.

If the project has no test setup, use the runner the toolchain already ships with
(for example `bun test`, `go test`, `cargo test`, Python's `unittest`). Adding a new test
dependency requires asking first.

Rationale: a failing test proves the test actually checks something, and a passing test
is the only objective, repeatable signal that the work is finished.

### II. Verification Before Done

Passing tests do not replace a runtime check. Before any change is reported as complete,
the change MUST be exercised in its real environment (browser, curl, CLI, or equivalent),
console and logs MUST be checked, and the evidence MUST be included in the report.

A change is never declared complete based on a successful edit alone.

Rationale: unit tests cover what the author thought to test. Running the thing catches the
rest.

### III. Simplicity and Minimal Change

Changes are the smallest that complete the task. Do not refactor, rename, or improve
surrounding code unless asked. Do not add helpers, wrappers, feature flags, compatibility
shims, or speculative code. Follow the existing style, naming, imports, and structure of
the file being edited. Remove code made obsolete rather than commenting it out.

Rationale: small, focused changes are easier to test, review, and revert.

## Development Workflow

- Every unit of work starts from a test, per Principle I.
- Work proceeds in red-green cycles. Do not batch many untested changes and test at the end.
- New files follow the existing project structure: tests live where other tests live,
  components where other components live.
- New dependencies, including test dependencies, require asking first.
- Documentation files (README, CONTRIBUTING, and similar) are not created unless asked.
  When files are deleted, the file tree in the README MUST be updated.

## Quality Gates

A change may be reported as done only when all of the following hold:

- Its tests were observed failing before implementation and passing after.
- The project's own checks (linter, formatter, type checker, existing test suite) pass.
- The change has been exercised at runtime and the evidence is in the report.
- No known security vulnerabilities were introduced and no secrets are hardcoded.
- No unused imports, variables, or dead code were added.

## Governance

This constitution supersedes other working practices for this project. Every spec, plan,
task list, and code review MUST be checked against it.

Amendments: propose the change, state the rationale, update this file, and bump the
version. Any complexity that violates Principle III MUST be justified in writing in the
plan that introduces it.

Versioning follows semantic versioning:

- MAJOR: a principle is removed or redefined in a backward-incompatible way.
- MINOR: a principle or section is added or materially expanded.
- PATCH: wording, clarifications, and non-semantic fixes.

Compliance review: at the end of each task, confirm the Quality Gates above were met before
reporting completion.

**Version**: 1.0.0 | **Ratified**: 2026-10-18 | **Last Amended**: 2026-10-18
