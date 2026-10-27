# Mojo 1.2 compatibility and migration

Use `Pipeline` and `Capture` for new native callback code. They select semantic
context before matching a callback. Existing free functions, `Piped`, Result
methods and iterator APIs remain available under their documented contracts.
The published FP Mojo 1.0.0 package targets Mojo 1.1; Mojo 1.2 users currently
use the `nightly` source checkout.

## Qualification checkpoint

The functional checkpoint is
[`0d9350e`](https://github.com/Spellbound-Mojo/fp_mojo/commit/0d9350e41608d530b9c47e73483947e702acd86e),
using Mojo 1.2.0 (2016d0cd) on Linux x86-64. Production sources, fixtures and
runner inputs stayed unchanged throughout qualification. The source and
precompiled package artifacts passed their retained-manifest audits; the
documentation matrix's bytecode matches the original qualified package.

<!-- compatibility: current-qualification -->

The complete positive suite and rejection fixtures ran at O3. Every executable
documentation example ran through both import routes at O0 and O3; this does
not claim a full-suite O0 run. Both benchmark programs executed, but their
timings were collected alongside compiler jobs and are diagnostic observations.

The [performance page](../architecture/performance.md#mojo-12-capture-qualification)
retains earlier cold-build observations at their named commits. Prior functional,
installation and measurement checkpoints remain in the downloadable catalog's
qualification history. This checkpoint adds no new performance claim.

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
retained in local `.cache` run folders; the catalog is a summary, not a portable
copy of those artifacts. The commands in
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

`Capture[E]` currently binds zero to two positional operands with read, mutable
or consuming conventions, followed by an optional homogeneous native keyword
pack. Empty packs need a type; larger packs, fixed named parameters and defaults
use an explicit native closure or OnceThunk. Stateful repeated calls use an
owned state value and a plain mutable-state function. These restrictions are
tracked for ergonomic review; they are not claims of arbitrary native-call parity.

## Pipeline migration coverage

Every legacy Piped method now has a selected counterpart in the catalog. The
documentation audit rejects missing, duplicate or stale assignments when the
API changes. The remaining-name inventory is empty:

<!-- compatibility: migration -->

Name coverage does not imply arbitrary family support. The catalog distinguishes
Result-specific operations from capabilities; custom dictionaries and deferred
families retain their public admission and execution contracts.

## Development sequence

The selected workflow, family admission, capability sequencing/filtering,
Capture pointer support, compilation measurements and clean-install passes are
complete for the scope above. Current ownership and execution contracts are
consolidated in the [architecture guide](../architecture/mojo12-redesign.md).

1. Prototype Resource scopes against the documented acquisition/use/release
   outcomes, exact error preservation and lifetime rejection cases.
2. Prototype fallible source advancement separately from stored Result elements,
   with terminal-state, no-read-ahead and cleanup checks.
3. Promote each complete contract through the existing invocation and execution
   owners; retain legacy APIs while replacement coverage grows.
4. Qualify every additional advertised platform and prepare a migration guide
   and explicit major-version decision before a stable release.

Each implementation pass includes focused verification, appropriate regression
gates, documentation, a commit and a push to `nightly`. Verification is run
locally; adding CI is outside this agreed sequence. Existing positional bindings
and legacy entry points remain supported during migration. New release versions,
deprecations and supported-platform claims must follow the demonstrated contract.
