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
`iterated`:

<!-- example: docs/examples/combinators.mojo -->

The eager chain keeps `3`, `4` and `5`, computes their squared sum as `50`, and
formats the result with `.then(report)`. Each eager stage completes before the
next starts. The lazy chain retains an iterator until `.sum_by(square)` consumes
it. `filter_not(positive)` keeps the two negative values instead.

The [API guide](../start/choosing-api.md) compares eager collection work, lazy
iteration, direct Result operations and native capture. Free functions in
[`fp.combinators`](../reference/combinators.md) remain available when a direct
function call fits the surrounding algorithm.

For a list literal, put its element type on the pipeline:
`pipeline[Int]([1, 2, 3]).map(square).get()`. Empty lists use the same form:
`pipeline[Int]([])`. A named List already carries its type, so
`pipeline(values^)` needs no type arguments. Mojo 1.2 leaves a bare call such
as `pipeline([1, 2])` ambiguous between List and the default Array literal.

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

Call `.raising[MyError]()` before native closures that can raise that type.
A raising plain function selects its own error when none is selected yet, so
`pipeline(text).then(parse_cents).then(closure)` needs no `.raising` when
`parse_cents` is a plain function; later stages see that error and a different
one is rejected. Closures cannot select it: inferring a closure's error crashes
Mojo 1.2 on a wrong argument convention.
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

Use `.traverse(callback)` when each payload produces an Optional, Result,
List or an effect recipe with a declared family. The pipeline infers the target family from the callback's return type.
Use `.sequence()` when the effects already exist. Both keep the source shape
inside the selected target effect and continue in that effect's family:

<!-- example: docs/examples/inferred_traversal.mojo -->

This follows [Cats' `traverse` and `sequence` workflow](https://github.com/typelevel/cats/blob/main/core/src/main/scala/cats/Traverse.scala). Native Optional stops on
absence, Result stops on its first stored error, and List enumerates ordered
combinations. Raised callback errors still use `.raising[E]()`; they are
independent of the stored Result error. Payload types, origins and permitted
move-only ownership are preserved.

Use an explicit family when choosing another policy, such as
`.traverse[Accumulate](validate)` to collect every `List` of errors,
`.traverse[ValidationFamily[Policy]](validate)` for another accumulation, or
an erased transformer layer. Reader, State, Writer and IO recipes identify
their family directly; see [effect-family inference](../reference/functions.md#inference-for-effect-recipes). Existing
explicit family and callback type bindings remain available.

The same target inference applies to the other Pipeline traversal methods:

| Call | Result on success |
|---|---|
| `traverse_tap(effect)` | Run effects while retaining the original payloads |
| `filter_effect(predicate)` | Keep payloads whose effect returns True |
| `traverse_filter(transform)` | Transform into effectful Optionals, keeping present values |
| `flat_traverse(transform)` | Transform into effectful collections and flatten the inner source shape |
| `traverse_void(effect)` | Run effects and discard their successful payloads |
| `sequence_filter()`, `flat_sequence()`, `sequence_void()` | Apply those policies to effects that already exist |

See the [complete traversal example](../reference/combinators.md#flatten-and-filter-effects).
Each method preserves its existing source-shape, ownership and error policy;
an explicit target selects validation, an erased transformer layer or a custom
policy that the carrier does not declare.

## Search with effects

`any_effect(predicate)`, `all_effect(predicate)`, `find_effect(predicate)` and
`find_map_effect(transform)` also infer native Optional, Result and List targets,
as well as declared effect recipes.
The first three borrow each item; `find_map_effect` consumes items to produce
an effect containing an Optional answer:

<!-- example: docs/examples/inferred_queries.mojo -->

`any_effect` stops on True, `all_effect` stops on False, and searches stop on
their first match. Absence or a stored error in the target effect also stops
Optional/Result queries. A successful search with no match keeps an empty
Optional inside its effect; `.raise_on_err()` propagates a stored Result error
and leaves that Optional answer intact.

Explicit `[Target]` bindings select another Monad policy or an erased layer.
Declared Reader, State, Writer and IO recipes supply their target family.
Native callback errors still use the pipeline's selected error type.
See [effectful queries and folds](../reference/functions.md#select-family-and-native-errors-before-callbacks)
for source consumption, empty answers and the explicit fold interfaces.

## Fold with effects

Use `.fold_effect(initial).run(step)` to reduce a source when each step returns
an Optional, Result or List. The initial value fixes the accumulator type before
the callback is matched; the callback result supplies the native effect family:

<!-- example: docs/examples/inferred_fold.mojo -->

The step consumes the accumulator and one item, returning the same accumulator
type inside its effect. Empty input returns the initial value in that effect
without calling the step. Optional and Result folds stop on absence or a stored
error. Native errors remain separately selected with `.raising[E]()`.

Binding consumes the source and accumulator without evaluating a callback. The
stage runs once; abandoning it releases both inputs. Move-only accumulators and
borrowed origins are preserved. Use `.fold_effect[Target](initial).run(step)` to
select a custom or deferred Monad policy explicitly.

## Sum effectful values

Use `.sum_by_effect(transform)` when each item produces a numeric Optional,
Result or List, and `.sum_effect()` when those numeric effects already exist.
Both infer the native effect, numeric type and SIMD lane count. They project
and add in one source pass, without collecting an intermediate list:

<!-- example: docs/examples/effectful_sums.mojo -->

Empty input yields zero inside the effect. Optional stops on absence, Result
stops on the first stored error, and List enumerates sums in branch order.
Addition follows source order, including floating-point rounding. Native callback
errors still use `.raising[E]()`. Use `[Target]` for a custom Monad policy;
Reader and State defer pulls and callbacks until execution. These conveniences
use the same fold as `fold_map_effect[Monoid]`.

## Combine effectful values

For a combining rule beyond numeric addition, use
`.fold_map_effect[Monoid](transform)`. The monoid supplies an empty value and
ordered combination; the callback supplies the Optional, Result or List effect.
This is the same pattern as [Cats' `foldMapM`](https://github.com/typelevel/cats/blob/main/core/src/main/scala/cats/Foldable.scala):

<!-- example: docs/examples/inferred_monoid_fold.mojo -->

`StringMonoid` concatenates successful strings. `ListMonoid[T]` concatenates
lists, and a custom `Monoid` can define another identity and combination.
Empty input returns that identity in the effect without calling the transform.
Optional and Result stop on failure; List keeps branch order. Use the existing
`[Target, Monoid]` form to select a custom or deferred effect explicitly.

When the effects already exist, use `.combine_all_effect[Monoid]()`:

<!-- example: docs/examples/combine_effects.mojo -->

This keeps the same target inference, identity, order and failure behavior,
without asking you to write an identity callback. Existing effects were
constructed before the call; explicitly selected deferred effects still execute
when run. Use `.combine_all_effect[Target, Monoid]()` for another Monad policy.
For numeric payloads, `.sum_effect()` also selects the combining rule for you.

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
leading arguments. Named shared unary chains can be passed directly to
pipeline callbacks: no `.copy()` or repeated wrapper is needed.

<!-- example: docs/examples/composition_reuse.mojo -->

`flow(add_one, double)` runs left to right; `compose(double, add_one)` runs
right to left. The same named chain can serve several pipelines. A chain
returning a native Optional, Result or List also supplies enough information
for `traverse` or `then` to select that effect family. Each operation keeps
its own short-circuiting and ownership rules.

Two-stage compositions can mix a plain function with a library callback
directly. `flow(add_one, partial(scale, 3))` adds one and triples the result;
`compose(partial(scale, 3), add_one)` does the same in reverse argument order.
The example also starts a binary chain with plain `add` and reuses it in
`scan_left`. No adapter is needed for the plain stage in these pairs.

Extend a composition with `.then(next)`. For example,
`price^.then(display).then(excited)` moves the existing pricing stages into a
chain that formats each price and adds `!`. Construction runs no callbacks;
`rendered(1)` and `rendered(2)` produce `"price=6!"` and `"price=9!"`.
Appending to a reverse `compose` chain still runs the new stage last.

Adapt a saved unary chain to new inputs with `.compose(before)`.
`rendered^.compose(add)` combines two quantities before running the same
pricing and formatting stages. Calling the resulting `combined(2, 3)` produces
`"price=18!"`. The new first stage determines the entry arguments; the saved
chain keeps its result type.

Use `chain^` when transferring its stages to an operation. A deferred operation
retains a borrowed chain until it runs or is discarded. Mutable and
consuming-only chains still require ownership; they are not implicitly shared.

Unary `partial` values support the same reuse: bind a prefix once, then pass the
callback by name to several operations. Each invocation still copies the bound
values as specified by `partial`; passing the callback does not copy its stored
prefix. The [partial application example](../reference/functions.md#bind-leading-arguments-with-partial)
shows a reusable multiplier and threshold predicate. A named partial also
works in `.filter`, `.filter_not`, `.tap_each`, `.pair_with`, `.ensure` and
`.fold`, borrowing each payload for the duration of the native call.

A stored `as_unary` adapter follows the same rule: reuse it by name, or pass
`callback^` to transfer its captures. The [native callback example](../reference/callables.md)
shows a formatter reused across two pipelines. Ordinary native functions and
closures need no adapter for direct Pipeline calls.

A wrapper generic over a family should forward its public
operation contract; the [wrapper guide](../guides/generic-wrappers.md) covers
that advanced case. Ordinary fluent calls need no such contract annotations.

Existing `pipe(value, first, second, ...)` and `piped(value)` code remains
supported. Their overload rules are documented under
[other pipeline entry points](../reference/functions.md#other-pipeline-entry-points).
Use `pipeline` as the starting point for new fluent code.

Next, see how [folds and lazy iterators](iteration.md) consume sources.
