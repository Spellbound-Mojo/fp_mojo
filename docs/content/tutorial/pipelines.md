# 1. Eager pipelines

Start with `pipeline(value)`, chain the operations you need, and finish with
`.get()`. Plain functions, closures and library callables work together without
adapters or a fixed stage limit. These tutorials use the Mojo 1.2 nightly
checkout; follow [installation](../start/installation.md#work-from-a-checkout)
and read [ownership and errors](../start/ownership.md) first.

<a id="run-a-pipeline-over-a-list"></a>
<a id="use-combinators-for-collection-stages"></a>

## Map and filter collection elements

A List pipeline already selects its elements. Use `.filter(predicate)` to keep
matching values, `.map(transform)` to change them, and `.sum_by(project)` to
project and sum in one pass. The same operations have lazy counterparts on
`iterated` and direct forms in `fp.combinators`:

<!-- example: docs/examples/combinators.mojo -->

The eager chain keeps `3`, `4` and `5`, computes their squared sum as `50`, and
formats the result with `.then(report)`. Each eager stage completes before the
next starts. The lazy chain retains an iterator until `.sum_by(square)` consumes
it. `filter_not(positive)` keeps the two negative values instead.

For an Array, `.elements()` selects element mapping and preserves its fixed
length. The Array of three integers becomes another Array of three integers.
A type-changing map can produce strings while keeping the same length.

<a id="choose-a-pipeline-form"></a>

## Choose between payloads and the whole value

`.map(transform)` follows the selected container: it maps List elements,
a present Optional payload, or a successful Result payload. Empty or failed
cases skip the callback. `.flat_map(next)` continues with another value in the
same selected context, such as a Result that can itself fail.

`.then(stage)` consumes the whole current value once. Use it to format a total,
process a complete collection, or switch to another carrier. Its returned List,
Optional or Result selects that native family for the next operation; other
values use Identity. A bare-value pipeline such as `pipeline(21)` also starts
with Identity, where `.map` applies once to the whole value.

For a named collection, `pipeline(values^)` moves it into the chain. Temporary
values need no move marker. `.get()` extracts the already computed carrier;
it does not trigger evaluation. Native collection operations are eager. An
explicit custom family can define deferred execution under its own contract.

<a id="mix-closures-and-library-values"></a>

## Mix functions, closures and partials

Use `.then(...)` for whole-value stages regardless of whether the stage is a
plain function, a captured closure or a library callable. The following example
uses all three forms without `as_unary`:

<!-- example: docs/examples/chained_pipeline.mojo -->

The ten stages compute `"total: $58.30"`. The `discount` and `ship` closures
capture ordinary arguments; `partial` binds the multiplier and coupon amount.
Each stage's input and output types are inferred.

<a id="stop-at-the-first-failure"></a>

## Select native errors once

Call `.raising[MyError]()` before native callbacks that can raise that type.
The example selects `PriceError` once and keeps it across all ten stages.
Pure callbacks and callbacks declaring `raises Never` remain non-raising.
If `parse_cents` raises, later stages do not run and the caller receives the
same `PriceError`. Library callables retain their declared error types.

A stored `Result.Err` is separate from a raised error. Result mapping and bind
skip a stored failure; a whole-value `.then(...)` can inspect it. Finish a Result
with `.value_or(on_err)` for error-dependent recovery, `.get_or(value)` for an
available default, `.get_or_else(factory)` for a lazy default, or `.to_optional()` to retain only success. These return the
plain value or Optional directly. To propagate a stored error as a native
exception, finish with `.raise_on_err()`; its raised type comes from the Result.
See [Results and recovery](results.md).

## Gather effects without family annotations

Use `.traverse(callback)` when each payload produces an Optional, Result or
List. The pipeline infers the target family from the callback's return type.
Use `.sequence()` when the effects already exist. Both keep the source shape
inside the selected target effect and continue in that effect's family:

<!-- example: docs/examples/inferred_traversal.mojo -->

This follows Cats' `traverse` and `sequence` workflow. Native Optional stops on
absence, Result stops on its first stored error, and List enumerates ordered
combinations. Raised callback errors still use `.raising[E]()`; they are
independent of the stored Result error. Payload types, origins and permitted
move-only ownership are preserved.

Use an explicit family when choosing another policy, such as
`.traverse[ValidationFamily[Policy]](validate)` for error accumulation or
`.traverse[Reader[Environment]](make_action)` for deferred execution. Existing
explicit family and callback type bindings remain available. Target inference
currently applies to `traverse` and `sequence`; derived traversal methods keep
their explicit target argument.

## Choose a constant or lazy default

Use `.get_or(value)` to finish an Optional or Result pipeline with an already
available default: `.get_or(0)` needs no callback or type arguments. The payload
type guides literal conversion, so a Float64 payload can also use `.get_or(0)`.
Both the carrier and the supplied default are consumed, including destruction
of an unused default. The returned payload retains its exact type and origins.

<!-- example: docs/examples/value_defaults.mojo -->

Mojo evaluates ordinary argument expressions before calling the method.
`get_or(compute_default())` therefore computes a default even when the payload
is present. Use `get_or_else(compute_default)` when that computation should
run only on absence or failure. Result values also expose both methods directly.

## Finish an Optional with a lazy default

`.get_or_else(make_default)` finishes a native Optional or Result pipeline with
a plain value. For Optional, the factory runs only when the Optional is empty;
a present value moves out without calling it. Pass the factory itself, keeping
expensive defaults lazy:

<!-- example: docs/examples/optional_default.mojo -->

This follows Cats Option's `getOrElse`, with Mojo's explicit zero-argument
factory. The factory must return exactly the payload type, including origins.
Nested Optionals stay nested in that payload: a present empty inner Optional
skips the default. Select native errors with `.raising[MyError]()` as for other
pipeline callbacks. Library factories retain their declared errors and are
consumed, including cleanup when skipped; native captured factories are borrowed.

## Map sequence elements

Use `pipeline(values^).elements()` for Array, Deque, LinkedList or NonEmptyList.
List is supported too; its ordinary pipeline already maps elements. The
container, element type and Array length are inferred, so no family import or
annotation is needed:

<!-- example: docs/examples/collection_families.mojo -->

Selection only moves the existing container. Array mapping preserves its fixed
length; Deque and LinkedList also support filter and filter_map. Filtering a
NonEmptyList produces a List because the result may be empty. `.elements()`
preserves the native error selected by `.raising[MyError]()`.

`pipeline(array^)` keeps its whole-value behavior until `.elements()` is called.
Use `pipeline_values(dictionary^)` for dictionary values and `iterated(values^)`
for lazy processing. Generic code can still name a family explicitly, as in
`pipeline[ArrayFamily[N]](values^)`.

<a id="forward-through-a-generic-function"></a>

## Reuse and generic code

Use `flow` or `compose` to build a reusable callable, and `partial` to bind
leading arguments. A wrapper generic over a family should forward its public
operation contract; the [wrapper guide](../guides/generic-wrappers.md) covers
that advanced case. Ordinary fluent calls need no such contract annotations.

Existing `pipe(value, first, second, ...)` and `piped(value)` code remains
supported. Their overload rules are documented under
[other pipeline entry points](../reference/functions.md#other-pipeline-entry-points).
Use `pipeline` as the starting point for new fluent code.

Next, see how [folds and lazy iterators](iteration.md) consume sources.
