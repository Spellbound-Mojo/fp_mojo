# Mojo 1.2 compatibility and migration

Use `Pipeline` and `Capture` for new native callback code. They select semantic
context before matching a callback. Existing free functions, `Piped`, Result
methods and iterator APIs remain available under their documented contracts.
The published FP Mojo 1.0.0 package targets Mojo 1.1; Mojo 1.2 users currently
use the `nightly` source checkout.

## Qualification checkpoint

The functional checkpoint is
[`dacbc9d`](https://github.com/Spellbound-Mojo/fp_mojo/commit/dacbc9d7f048f7fc12527bfebfde53ce09193665),
using Mojo 1.2.0 (2016d0cd) on Linux x86-64. Retained compiler inputs are verified
against this commit and stayed unchanged throughout complete qualification.
The precompiled package is bound to the production sources by its retained
manifest and artifact hashes. The checkpoint update itself
changes documentation only.

<!-- compatibility: current-qualification -->

Both source and precompiled-package imports passed the complete O3 corpus:
1,078 maintained programs, 2 diagnostic benchmarks and 2,904 rejection fixtures
per route. All 119 documentation examples additionally passed their full
standalone source/package O0/O3 matrix: 476 builds with exact output checks.
This checkpoint includes the shared traversal contracts and direct reusable
iterator callback APIs. It does not replace the focused O0/O3 ownership and
rejection matrices recorded for their individual implementation passes.

The rejection fixture for an invalid `traverse_tap` callback now expects the
shared `TraverseTapContract` diagnostic. Its Mojo body is unchanged, and the
corrected fixture additionally passed source/package O0/O3 checks with normal
compiler rejections. The complete checkpoint includes that correction and the
Pipeline outcome/recovery additions present in the named commit.

The rejection corpus retains explicit type hints in its documented legacy
controls; these results do not establish universal crash-free diagnostics for
invalid calls. Benchmarks ran alongside compiler jobs and remain diagnostic.
Cold compilation cost, copied-source delivery, other platforms and private
experimental suites were not requalified in this checkpoint.

Earlier cold-build and paired-comparison observations remain associated with
their named commits on the [performance page](../architecture/performance.md#mojo-12-capture-qualification).
Prior functional, installation and measurement checkpoints remain in the
catalog's qualification history.

## Historical baseline

The baseline below qualifies production source at
[51997ac](https://github.com/Spellbound-Mojo/fp_mojo/commit/51997aca96c3256a90bf6abdd4074a79f517a117)
with Mojo 1.2.0 (2016d0cd), Linux x86-64. Later migration passes have their own
retained reports; this checkpoint does not silently advance when code changes.
All baseline reports have unchanged inputs and zero audit failures.

<!-- compatibility: qualification -->

The checkpoint also passed 38 tooling tests and a strict documentation build.
The [downloadable catalog](../downloads/docs/compatibility.json) records the
source commit, production tree, report digests, representative evidence,
operation contracts and migration assignments. Raw logs and executables are
retained in local `.cache` run folders or hash-verified archives; the catalog
is a summary, not a portable copy of those artifacts. The commands in
[development](../contributing/development.md#verification-gates) reproduce the gates.

macOS arm64 has a locked environment but has not been qualified on Mojo 1.2 in
this work. Device compilation does not establish GPU execution support. A green
host suite does not prove that every invalid legacy native call diagnoses
normally: the catalog identifies the 22 historical diagnostic controls that
bind callback types explicitly. Crashes and timeouts never count as rejection.

## Package coverage

Every public package is classified below. The reviewed export inventory owns
individual names and signatures; this catalog adds scope, restrictions and
representative checked clients. A package's examples do not imply exhaustive
coverage of all native signatures. Its reference and architecture pages retain
the detailed operation contracts.

<!-- compatibility: packages -->

## Selected Pipeline contracts

`selected` means the operation is exposed through the selected family/native
error boundary. `result_only` means the current method requires a Result
carrier, even when a same-named legacy operation also accepts generic families.
Method-name equality alone does not establish feature parity.

<!-- compatibility: pipeline -->

Native closures retain their borrow origins; stored thin pointers keep their
native calling conventions. Library callbacks retain their declared receiver
modes and errors. `raising[E]()` selects subsequent native callback admission;
it is independent of stored Result errors and does not bound every family or
library-callable error. Construction and deferred execution can raise different
errors at different times. Generic forwarding carries the family's public
admission predicates in the signature, including embedded origins.

Effectful queries and reductions now select a Monad target. The selected binary
fold binds its accumulator first: `fold_effect[Target](initial).run(step)`.
This avoids Mojo 1.2's crash while inferring an accumulator and diagnosing an
incompatible native argument convention together. Legacy `Piped` calls keep
their existing order. Array sources use temporary List storage to preserve
move-only ownership across native iterator moves.

`Capture[E].args(...)` binds zero to eight consumed positional operands; an
all-owned bundle can also grow with `take`. Mixed read, mutable and consuming
conventions support up to three positional operands. A homogeneous native
keyword pack can follow at most three positional operands; an empty pack needs
its type or a typed dictionary. Fixed named parameters, defaults and larger
mixed calls use an explicit native closure or OnceThunk. Stateful repeated
calls use an owned state value and a plain mutable-state function. See the
[argument-binding tutorial](../tutorial/results.md#bind-arguments-before-the-callback)
for executable examples and ownership rules.

## Pipeline migration coverage

Every legacy Piped method now has a selected counterpart in the catalog. The
documentation audit rejects missing, duplicate or stale assignments when the
API changes. The remaining-name inventory is empty:

<!-- compatibility: migration -->

Name coverage does not imply arbitrary family support. The catalog distinguishes
Result-specific operations from capabilities; custom dictionaries and deferred
families retain their public admission and execution contracts.

## Current contracts

The selected workflow, family admission, capability sequencing/filtering,
Capture pointer support, compilation measurements and clean-install passes are
complete for the scope above. Current ownership and execution contracts are
described in the [architecture overview](../architecture/overview.md),
[algebra contracts](../architecture/algebra.md), and
[generic wrapper guide](generic-wrappers.md).

Existing positional bindings and legacy entry points remain supported. New
release versions, deprecations and supported-platform claims must follow the
demonstrated contract. The [development guide](../contributing/development.md)
lists the maintained verification commands.

## Async preview qualification

The opt-in [async preview](async-runtime.md) adds two reviewed namespaces and
six executable examples. Its focused source/package O0/O3 checks are recorded
separately from the complete-corpus reports above, which retain their recorded
commit and do not claim a new full-suite run for the preview. The
[async architecture](../architecture/async-state-machines.md) describes the
maintained public, ownership and origin checks. The completed
[overnight qualification](../architecture/async-qualification.md#overnight-results)
adds twelve one-hour source/package O0/O3 stress cases, bounded retained storage
and separate serial performance diagnostics on pinned Linux x86-64.
