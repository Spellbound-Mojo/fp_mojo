# Code design

Agents must not duplicate code or reimplement concepts that already have a
canonical implementation. Keep deduplication in mind throughout planning,
implementation, and review, including across package boundaries.

Before adding a mechanism, find its existing owner and consumers. Reuse or
generalize the most fundamental suitable abstraction, then make user-facing
submodules delegate to it. Shared semantics must have one implementation;
public overloads may adapt native signatures but must not copy execution,
validation, ownership, or error-handling logic.

Design the complete feature contract before editing. Preserve native types,
effects, ownership, and origins when sharing code; do not weaken those guarantees
to force reuse. Explain any unavoidable native-signature boundary in the code.

# Project scope

Implement functionality in this library. Changes to Mojo's compiler or standard
library are outside this project's scope and must not be scheduled as its next
development pass. External source inspection may inform library design.

A rejected native encoding does not prove that the feature has no library-level
solution. Consider different library representations and invocation boundaries.
Identify any resulting changes to the documented contract or the public API
explicitly before implementing them; do not silently weaken ownership, origins,
or error semantics.

# Working agreements

- Discuss before building. For a design question or a request for a plan,
  present the analysis and the plan and wait for agreement before prototyping.
- Ask before any public API or behavior change, and before destructive or
  outward-facing actions.
- Commit or push only when asked.
- Prefer native Mojo types and mechanisms over library machinery; accept native
  limitations rather than emulating another language.
- Test as you go with targeted runs instead of waiting for full-suite baselines.
  Estimate durations before multi-hour jobs and prefer parallel runs.
- Report failures and skipped steps plainly.
- Document design decisions in the MkDocs site (`docs/content/`), not in loose
  notes elsewhere in the repository. `docs/content/contributing/development.md`
  lists the environment, verification gates and Mojo 1.1 practices.
