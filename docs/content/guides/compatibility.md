# Mojo 1.2 compatibility and migration

Use `Pipeline` and `Capture` for new native callback code. They select semantic
context before matching a callback. Existing free functions, `Piped`, Result
methods and iterator APIs remain available under their documented contracts.
The published FP Mojo 1.0.0 package targets Mojo 1.1; Mojo 1.2 users currently
use the `nightly` source checkout.

## Qualification checkpoint

The functional checkpoint is
[`a89e752`](https://github.com/Spellbound-Mojo/fp_mojo/commit/a89e7525dc0d8da7ed615bc853251c00ec134381),
using Mojo 1.2.0 (2016d0cd) on Linux x86-64. Production sources, fixtures and
runner inputs stayed unchanged throughout qualification. The precompiled
package is bound to those sources by its retained manifest and artifact hashes.
The checkpoint update itself changes documentation only.

<!-- compatibility: current-qualification -->

The complete positive suite and rejection fixtures ran through both source
and precompiled-package imports at O3. Each import route passed 1,029 programs
and two diagnostic benchmarks, plus 2,716 rejection fixtures. The ten API-quality
reference workflows passed all 40 source/package O0/O3 builds. All 117 examples
also ran inside both complete O3 suites. The full standalone documentation
matrix and copied-source delivery were not rerun.
Both benchmark programs executed alongside compiler jobs; their timings are
diagnostic observations. The rejection corpus retains explicit type hints in
its documented legacy controls; it does not prove universal crash-free
diagnostics for invalid calls.

The [performance page](../architecture/performance.md#mojo-12-capture-qualification)
retains earlier cold-build observations at their named commits. Prior functional,
installation and measurement checkpoints remain in the downloadable catalog's
qualification history. The [API-quality comparison](../architecture/api-quality.md#milestone-comparison)
adds nine isolated cold builds of three clients under the same policy. Their
costs remain close to the baseline; the sample does not establish a speedup.

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

## Development sequence

The selected workflow, family admission, capability sequencing/filtering,
Capture pointer support, compilation measurements and clean-install passes are
complete for the scope above. Current ownership and execution contracts are
consolidated in the [architecture guide](../architecture/mojo12-redesign.md).

The [API quality roadmap](../architecture/api-quality.md) now orders work around
ten maintained workflows and concrete Cats/Cats Effect reference examples:
preferred entry points, consistent ownership, simpler callback binding, generic
contracts, generator consolidation and milestone qualification. Resource
composition and IO finalization are existing baseline workflows in that plan.

Each implementation pass includes focused verification, appropriate regression
gates, documentation, a commit and a push to `nightly`. Verification is run
locally; adding CI is outside this agreed sequence. Existing positional bindings
and legacy entry points remain supported during migration. New release versions,
deprecations and supported-platform claims must follow the demonstrated contract.
