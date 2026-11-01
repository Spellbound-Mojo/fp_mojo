# Mojo 1.2 compatibility and migration

Use `Pipeline` and `Capture` for new native callback code. They select semantic
context before matching a callback. Existing free functions, Result methods and
iterator APIs remain available under their documented contracts. The former
`Piped` struct and `piped` factory were removed; see
[Pipeline migration coverage](#pipeline-migration-coverage).
FP Mojo 1.0.2 targets Mojo 1.2; FP Mojo 1.0.0 and 1.0.1 target Mojo 1.1.

## Qualification checkpoint

FP Mojo is qualified on Mojo 1.2.0 on 64-bit Linux. The qualification suite
verifies both direct source imports and precompiled `.mojoc` package imports
across optimization levels (`O0` and `O3`), ensuring exact runtime output and
predictable compiler diagnostics.

<!-- compatibility: current-qualification -->

The qualification matrix covers maintained programs, diagnostic benchmarks, and
compile-rejection fixtures. Documentation examples pass standalone source and
precompiled package builds with exact output verification across optimization levels.

Earlier benchmark observations and paired comparisons are recorded in the
[performance guide](../architecture/performance.md#mojo-12-capture-qualification).

## Historical baseline

The baseline below records qualification checks for production sources under
Mojo 1.2.0. Every checked build adheres to strict verification gates, zero audit
failures, and clean documentation validation.

<!-- compatibility: qualification -->

The qualification catalog records source trees, test digests, operation contracts,
and migration assignments. The verification commands in the
[development guide](../contributing/development.md#verification-gates) reproduce
all qualification gates locally.

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
incompatible native argument convention together. Array sources use temporary List storage to preserve
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

`Piped` and `piped(value)` were removed. Replace `piped(value)` with
`pipeline(value)` and `piped(dictionary^)` value operations with
`pipeline_values(dictionary^)`. Pipeline has every method Piped had, and
`.then(...)` chains have no stage limit. Pipeline closures use the selected
native error: call `.raising[MyError]()` once before a raising closure. A
raising plain function selects its error itself. Piped inferred each closure's
error, which could crash Mojo 1.2 on an invalid closure convention. Per-method
family selection such as `.map[Family](f)` or `.recover[Family](h)` moves to
the start: `pipeline[Family](value).map(f)`. To switch family mid-chain, start
again with `pipeline[Other](previous^.get())`; `then[J]` still selects the output
family of a whole-value stage. Keyword error hints such as `[R=R, X=E]` become
one `.raising[E]()` before the stage. `fold_effect[G](step, initial)` becomes
`fold_effect[G](initial).run(step)`, or `fold_effect(initial).run(step)` to
infer `G`.

Every retired Piped method has a selected counterpart in the catalog. The
documentation audit rejects missing, duplicate or stale assignments when the
API changes. The remaining-name inventory is empty:

<!-- compatibility: migration -->

Name coverage does not imply arbitrary family support. The catalog distinguishes
Result-specific operations from capabilities; custom dictionaries and deferred
families retain their public admission and execution contracts.

The `fp.combinators` package was removed; it only re-exported other packages.
Import `map`, `filter`, `fold_left` and the other collection functions from
`fp.iteration`, and `if_effect` from `fp.algebra`. Operation contracts such as
`MapContract` moved from `fp.algebra` to
[`fp.algebra.contracts`](../reference/algebra.contracts.md).

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

The opt-in [async runtime preview](async-runtime.md) introduces structured
asynchronous execution, lightweight fibers, deterministic virtual-time testing,
and multi-threaded work-stealing scheduling. The implementation is verified
through focused source and precompiled-package suites, bounded-storage stress
cases, and deterministic integration tests. For details on execution contracts,
see the [async architecture](../architecture/async-state-machines.md) and the
[async runtime guide](async-runtime.md).
