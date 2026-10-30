# Support and limitations

This page lists supported platforms and the limits that affect how you call the
library. For each restricted form, the table describes what works today.
[Native Mojo boundaries](../architecture/native-boundaries.md) explains the
compiler constraints behind these choices.

## Platforms

| Item | Status |
|---|---|
| Compiler | Mojo 1.2.0 (2016d0cd), pinned through Pixi for `nightly`; published FP Mojo 1.0.0 requires Mojo 1.1.0 |
| Linux x86-64 | The [verified checkpoint](compatibility.md#qualification-checkpoint) passes the full positive and rejection suites. Selected Pipeline/Capture admission and retained legacy diagnostic restrictions are classified in the inventory. |
| macOS arm64 | Locked environment available; last runtime verification was on Mojo 1.1.0 |

The [compatibility inventory](compatibility.md) distinguishes selected, legacy
and pending APIs and records their qualification evidence.

## Combinator support

The table below records the implemented combinator groups.

These combinators remove wrapper lambdas from container and Result chains.
Capability operations own execution; fluent methods delegate to them. Native
origins, callback receiver modes and the distinction between stored and raised
errors remain part of every operation's contract.

| Group | Scope | Status |
|---|---|---|
| 1 | Fluent `map2` and `product` on Piped, including Result carriers | Implemented |
| 2 | `traverse_void` and `traverse_tap` for container and iterator pipelines | Implemented for the [documented source families](../reference/combinators.md#containers-and-capabilities) |
| 3 | Selective recovery (`recover_if`, `or_else_if`), effectful error observation (`flat_tap_err`) | Implemented on Result and Piped |
| 4 | `map_both`, `redeem`, `redeem_with`, whole-outcome observation (`attempt_tap`) | Implemented on Result and Piped |
| 5 | `sequence_void`, `flat_traverse`, `flat_sequence`, `filter_effect` and `traverse_filter` | Implemented for the [documented source families](../reference/combinators.md#containers-and-capabilities) |
| 6 | Effectful folds and predicates (`fold_effect`, `any_effect`, `all_effect`), conditional composition (`if_effect`) | Implemented; see [effectful reductions](../reference/combinators.md#fold-and-choose-effects) |
| 7 | Fluent `ap`, multi-argument mapping and tuple construction | Implemented as `ap`, `map_n` and `product_n`; see [combination contracts](../reference/combinators.md#combine-and-inspect-effects) |
| 8 | Kleisli composition of functions returning an effect | Implemented; shared composition engine and automatic `.map(chain)` adaptation |
| 9 | Parallel validation with error accumulation, `par_map_n` and `par_traverse` | Implemented; type-preserving Result accumulation through Semigroup |
| 10 | Parallel products and sequencing, `par_product_n` and `par_sequence` | Implemented through the existing n-ary runner and identity traversal |
| 11 | Monad and iterator sequencing, `flat_tap`, `followed_by` and `before` | Implemented through shared retention and the existing map/bind operations |
| 12 | Effectful pairing, `flat_pair_with`, across Monad families and Iter | Implemented through the existing paired retention mode |
| 13 | Shared stored-error capability and generic `recover`/`or_else` | Implemented for ResultFamily, ValidationFamily and ResultT |
| 14 | Lift error recovery through ReaderT, WriterT, OptionalT and StateT | Implemented; [transformer recovery contracts](../architecture/algebra.md#shared-error-handling) |
| 15 | Shared conditional recovery (`recover_if`, `or_else_if`) | Implemented through ApplicativeError |
| 16 | Shared error observation (`tap_err`, `flat_tap_err`) | Implemented through ApplicativeError |
| 17 | Shared success validation (`ensure`) | Implemented through Monad and ApplicativeError |
| 18 | Shared outcome composition (`redeem`, `redeem_with`, `attempt_tap`) | Implemented with a fixed stored-error type |

The acyclic layering contract is enforced by tooling. Algebra conveniences on
Result now use `piped(result^)`; see the [migration](../architecture/data.md#migration-from-the-first-nightly-fluent-api).
NonEmptyList, its concatenation Semigroup and its shape-preserving family are
implemented; see [non-empty validation](../reference/data.md#non-empty-collections-and-validation).
Success with warnings is implemented as Ior with explicit sequential and
accumulating families; see [inclusive-or](../reference/data.md#success-with-warnings).
The first public MTL slice, Ask/Local with explicit transformer lifting, is
implemented; see [environment capabilities](../reference/effects.md#program-against-environment-capabilities).
Stateful with explicit transformer lifting is implemented; see
[selected state capabilities](../reference/effects.md#program-against-a-selected-state).
Tell/Listen/Censor with explicit transformer lifting is implemented; see
[selected log capabilities](../reference/effects.md#program-against-a-selected-log).
Fallible stream transformations and composable Resource scopes remain subsequent
slices.

Before fallible streams, an [iterator expansion](../architecture/iteration.md#iterator-expansion)
adds native adapter method chains, consuming terminals, lazy partitioning with
explicit buffering policies, and alignment, with stateful and effectful
follow-ups. Partition, partition_map and unzip return iterator branches;
collection stays explicit. I1 through I6 are implemented: native adapter method
chains, consuming terminals, branching with explicit buffering, alignment, scans
and effectful searches. See the [implementation contracts](../architecture/iteration.md#implementation-passes).

The approved combinator proposal is complete for the documented capability
families. Shared operations derive from family primitives; no operation requires
a separate implementation for each container. Generalizing error-type-changing
operations is outside this proposal; existing Result methods remain available.

Pass 1 consumes two already evaluated operands. List combination is Cartesian,
in left-major order, and requires copyable elements because a value participates
in several outputs. Optional and Result combine at most once and admit move-only
payloads; Result keeps the first stored error. Native callbacks are borrowed in
place, library callbacks are consumed, and native errors propagate unchanged.
Piped infers List, Optional and Result families; other Applicative families are
selected explicitly. Existing `map2_lazy` remains the factory-based operation.

Pass 2 derives traversal conveniences from the existing source traversal and
target accumulation loops. `traverse_tap` retains the original inputs and the
source shape; a source Result's stored error remains inside the target effect.
`traverse_void` discards effect payloads without building a result collection.
For a Result source, the output preserves the source error as an inner
`Result[NoneType, E]` in the target effect. A source `Err` skips the callback; an `Ok` sequences the callback effect
and replaces its successful payload with `None`. This preserves the library's
existing distinction between source errors and target-effect failures.

Pass 3 borrows stored errors for predicates and consumes only matching errors
in recovery callbacks. Both conditional recovery methods keep `Result[T, E]`,
so an unmatched error passes through unchanged. `flat_tap_err` sequences an
error observer: observer success retains the original error, while observer
failure replaces it. These methods reuse Result's transformation, predicate
and retention machinery; native raised errors propagate unchanged.

Pass 4 selects exactly one handler from the original Result branch, using
`(on_ok, on_err)` order. `map_both` can change both payload types; `redeem`
wraps either handler's value in `Ok`; `redeem_with` returns the selected
handler's Result. `attempt_tap` borrows the whole outcome once and retains it
on observer success, or replaces it with the observer's stored error. Owned
folds and transformations now share one branch-selection implementation.

Pass 5 derives `flat_traverse` from source traversal and monadic flattening,
and `traverse_filter` from traversal and `FunctorFilter` compaction. `filter_effect`
borrows each input for an effectful Bool predicate and retains accepted inputs.
`flat_sequence` and `sequence_void` use identity callbacks. Result source errors
stay distinct from target-effect failures; filtering requires a source family
that can represent absence. No additional per-container primitive is needed.

Pass 6 uses one dependent fold driver for iterable sources and eager Monad
targets; Reader and State defer it until `run`. Effectful predicates stop on
the first decisive Bool in each branch. `if_effect` binds an effectful Bool
to one of two factories; use `piped(result^)` for a Result condition.
Native raised errors stay separate from stored failures.

Pass 7 adds `ap`, `map_n((second, third), combine)` and
`product_n((second, third))` to Piped, including Result carriers. The receiver is the first
operand and products are flat tuples. All three share the existing Applicative
primitives. Native callbacks take one to eight arguments; tuple-taking library
callbacks and products are variadic for inferred List, Optional and Result.
Explicit families support up to eight operands.

Pass 8 adds `kleisli[Family](parse).then(validate).map(render)`, reverse
composition with `compose`, and input adaptation with `contramap`. Shared,
mutable and consuming calls preserve callback ownership and deferred origins.
Eager pipelines and lazy iterators accept `.map(chain)` directly through one
internal callable-view protocol; `flat_map` and traversal share that admission.
Pass 9 adds `par_map_n` and `par_traverse`, backed by
`ValidationFamily[ErrorCombiner]`. Default inference concatenates list-valued
stored errors; explicit Semigroup policies keep custom error types intact.
Native raises still stop immediately, and ordinary Result composition keeps
its short circuit behavior. Result combination and native accumulation share
their existing execution owners.

Pass 10 adds `par_product_n((second, third))` on Piped holding
Result, and `par_sequence()` on the same Piped and Iter sources as
`par_traverse`. Products are variadic flat tuples; sequencing preserves source
shape, stored error types and native origins. Both accept an explicit error
Semigroup and reuse the existing execution and cleanup mechanisms.

Pass 11 extends `flat_tap`, `followed_by` and `before` to Piped's Monad families
and lazy Iter. Piped infers List, Optional and Result; other families are
selected explicitly. Retention copies per branch for List and Iter and moves
single-use payloads for Optional and Result. Reader and State defer callbacks
until run. Existing Result methods, traversal and the new methods share one
retention mechanism.

Pass 12 extends `flat_pair_with` to the same Monad families and Iter. It
borrows each original for the projection and emits `(original, projected)` per
successful branch. Branching copies only the original; projected values move
into their pairs. Single-use families admit move-only values on both sides,
and deferred timing, stored errors and native origins follow the family.

Pass 13 adds **shared error handling** through `ApplicativeError` for
ResultFamily, ValidationFamily and ResultT. `fail[Family, A](error)` constructs
a stored failure; explicit-family Piped `recover` and `or_else` handle that
selected layer. Recovery derives once from `or_else` and `pure`. Result owns
branch selection and cleanup, and ResultT reuses its generalized bind guard.
Native raises keep their exact types; existing inferred Result syntax remains
available, including error-type-changing `or_else`.

Pass 14 lifts the capability through ReaderT, WriterT, OptionalT and StateT
when their base Monad supports it. StateT recovery uses the input state at the
recovery boundary and requires a copyable state; ResultT above State keeps the
updated state and allows move-only state. Reader retains its borrowed
environment, Writer uses the handler's log on base failure, and OptionalT
preserves absence. All delegate to the selected base error layer.

Pass 15 generalizes `recover_if` and `or_else_if` through ApplicativeError.
The predicate borrows each selected error; matching errors move into the
handler and non-matches pass through the family's failure constructor.
Result and generic families share the same predicate guard. Existing branch
joins serve both eager and deferred carriers, including Validation without bind.

Pass 16 generalizes `tap_err` and `flat_tap_err` through the same capability,
including lifted transformers. Both borrow the selected error and skip success.
`tap_err` discards the observer's return value. `flat_tap_err` sequences its
effect with the retained failure using the family's combination policy:
Result keeps an observer failure; Validation accumulates observer errors before
the original errors. Result's existing methods delegate to this implementation.

Pass 17 generalizes `ensure(predicate, make_error)`. Both callbacks borrow
the success, and the error factory runs only on rejection. Existing failures
skip both callbacks. The operation requires Monad and ApplicativeError; native
constructor errors and deferred execution keep the selected family's contract.

Pass 18 generalizes `redeem`, `redeem_with` and `attempt_tap`. The selected
stored outcome is exposed internally as a native Result through map and
recovery. Result owns branch selection; the existing effect-retention adapter
owns observation. `redeem` requires ApplicativeError and works with Validation.
The other two require Monad as well. Both outcome handlers keep the family's
stored-error type, and handler failures never select another handler in the
same operation. See [shared outcomes](../reference/combinators.md#validate-and-observe-outcomes).

The source references are Cats' [Apply](https://github.com/typelevel/cats/blob/main/core/src/main/scala/cats/Apply.scala),
[Traverse](https://github.com/typelevel/cats/blob/main/core/src/main/scala/cats/Traverse.scala),
[error handling](https://github.com/typelevel/cats/blob/main/core/src/main/scala/cats/ApplicativeError.scala),
[Kleisli](https://typelevel.org/cats/datatypes/kleisli.html) and
[Parallel](https://typelevel.org/cats/typeclasses/parallel.html).

## Known boundaries

| Area | Current behavior |
|---|---|
| Partial application | `partial` binds a positional prefix of up to eight arguments of a plain function. It does not bind keywords, reorder arguments, accept capturing targets, `mut` parameters or owned remaining parameters, or nest. A native closure expresses all of these. |
| Lazy iteration callbacks | They cannot raise; carry failures as `Result` elements. |
| Match clauses | `fp.match` and `fp.rewrite` take one to sixteen clauses: plain functions or lambdas without captures. Data a clause needs is passed with `context=` or as a component of a tuple of values. |
| Pipeline stages | `pipe`, `flow` and `compose` take two to eight plain functions directly. A closure is promoted with `as_unary`, and then every native function in that chain is promoted too. `piped(value).then(f)...get()` chains any number of plain functions, closures and library values. |
| `action` endpoints | `action` takes library endpoints (`BorrowCallable` for Reader, `Unary` for State): a plain function with read parameters would match both native forms. |
| Algebra and effect callbacks | `map`, `flat_map`, `traverse`, `modify`, `censor` and `local` take native functions or closures. Free `map2`, `map2_lazy` and `ap` take library values; fluent `map2` accepts native functions and closures too. |
| Capture | `Capture[E]` binds up to eight consumed positional operands, or up to three mixed read/mutable/consuming operands with an optional homogeneous native keyword pack, before callback admission. `Capture.stateful` owns explicit mutable state for repeated plain-function calls. Tested invalid calls diagnose without callback-type bindings. |
| Selected pipeline | `pipeline(value).raising[E]()` selects native errors once for family operations and Result combinators. Pipeline is the preferred selected interface; every legacy Piped method name has a classified counterpart. Matching names do not imply interchangeable signatures or ownership contracts. |
| Legacy `attempt` call shapes | Zero to two positional arguments; callbacks with homogeneous native keyword packs use `attempt_kwargs`, including empty packs. Other call shapes use a closure. On Mojo 1.2, optional named convention selectors cover all supported positional combinations; `mutating`, `consuming`, `mut_owned` and `mut_owned_kwargs` remain supported. An incompatible selector needs an explicit `F` hint to diagnose normally; incompatible adapter diagnostics remain incomplete. See the [reference](../reference/data.md#select-a-native-argument-convention). |
| Named or defaulted parameters | Pass a native function with named or defaulted parameters to library functions through a closure that spells the call. |
| Closures with owned mutable state | Unannotated native callbacks can lose updates at O3 on Mojo 1.2. Use the documented always-inline requirement, explicit mutable library callables or Capture.stateful. |
| Closures with embedded origins | Some closures that combine embedded origins with captured state fail to compile on Mojo 1.1; pass borrowed views as arguments instead. |
| Same-named types in several modules | Two modules of one program that define same-named types and spell the same function type over them fail to compile on Mojo 1.1 (`invalid redefinition of 'def(...)'`); give those types distinct names ([details](../architecture/native-boundaries.md#known-compiler-defects)). |
| Generic wrappers | Selected native calls fix their error with `raising[E]()`. Generic family wrappers retain public admission predicates in their signatures, including carrier and error origins. Legacy native forwarders retain their documented explicit error bindings. |
| Match ownership | Matches borrow their subject and return values, never references into it; consuming access belongs to the types (`Result.fold_owned`, `Choice.unwrap`, `Optional.take`). |
| Guards and coverage | A guard is opaque to coverage: a guarded clause never covers a constructor alone. |
| Match size | Sixteen clauses per match and three subjects; clauses do not capture, so data they need comes through `context=` or a subject. |
| Native `Variant` | A native `Variant` is not a match subject; declare the type with `Data` and store it in a `Choice`. The [matching limits](../architecture/matching.md#limits) give the full list. |
| `local` | `local` rejects a base whose result keeps the environment. |
| Deferred Reader and State callbacks | Compositions, traversals and effectful reductions borrow native callbacks until the computation runs; keep them alive and unmoved, or supply an owned library callback (`as_unary(f^)` for unary functions). |
| Running a raising deferred computation | Its error cannot propagate from a function declared with a plain `raises`; catch it with `try`/`except`, where it keeps its exact type. |
| State traversal | Requires a base whose carrier keeps one type across steps. |
| `pure` over `WriterT` | Requires a monoid whose `empty` does not raise. |

When a program runs into one of these boundaries,
[troubleshooting](troubleshooting.md) lists the compiler messages and what to
check for each.
