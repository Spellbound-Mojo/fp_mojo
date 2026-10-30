# fp.iteration

`fp.iteration` provides lazy mapping, filtering and scans, together with folds,
reductions and searches over native iterators and owned collections. The
[iteration tutorial](../tutorial/iteration.md) follows values through a lazy
chain and shows how a terminal operation consumes them. The
[callback guide](../start/ownership.md#reuse-callbacks-by-name) explains named
reuse, explicit moves, and the independent ownership of callback inputs.

<!-- api: iteration -->

## Use a non-empty source guarantee

`reduce_non_empty(values, step)` returns the accumulator directly, seeded from
the first element. `reduce_map[Semigroup](values, projection)` combines mapped
values without requiring an empty identity. `combine_non_empty[Semigroup]`
combines the original elements. Each takes NonEmptyList, moves payloads and
preserves left-to-right order. A singleton skips the binary combine operation.

`minimum_by_non_empty` and `maximum_by_non_empty` borrow each element to compute
its key once and return the selected owned element directly. Equal keys keep
the earliest element. Callback errors keep their native types and destroy the
unvisited suffix; ordinary Lists use the existing Optional-returning reductions.

<!-- example: docs/examples/non_empty_reductions.mojo -->


## Stateful mapping

`map`, `filter_map` and `flat_map` accept both shared `Unary` and stateful
`MutableUnary` library callbacks, in free-function and fluent forms. For
example, `.map(Running(0))` retains a running total between pulls. Move a named
stateful callback into the iterator with `callback^`; construction calls it
zero times. The iterator owns and releases its state when exhausted or dropped.
`filter_map` still infers the Optional payload, and `flat_map` exhausts each
returned inner source before invoking the callback for the next outer element.

<!-- example: docs/examples/iteration.mojo -->

`scan_left` likewise accepts shared or mutable binary steps directly. The
example's `.scan_left(IncreasingWeight(1), 0)` changes its weight between
inputs while yielding `[0, 1, 5, 14]`. It yields a copy of the initial
accumulator before pulling any input or calling the step, then one snapshot
per input. The accumulator must remain Copyable; callback captures and input
elements can be move-only. Use `scan_map` when carry and output should differ
or the carry cannot be copied.

An owned callback uses its mutable receiver when it has one, otherwise its
shared receiver. A consuming-only callback cannot serve repeated lazy calls.
Named shared partials, compositions and other supported wrappers retain their
existing borrowed reuse. All lazy callbacks must be non-raising; return
`Result` elements to represent domain failures. Native closures keep their
existing signature and owned-capture requirements.

## Stateful folds and reductions

`fold_left`, `fold_until`, `reduce_optional` and both `reduce` forms accept
owned shared or mutable library callbacks, through free functions and Iter
methods. Selected `Pipeline.fold_left`, `reduce_optional` and `fold_until`
accept the same callbacks; `Piped.fold_left` also accepts owned mutable steps. For example, `.fold_left(IncreasingWeight(1), 0)` returns `14` over
`[1, 2, 3]`, retaining the changing weight between steps without an adapter
or a closure. Move a named stateful step with `step^`, or pass `mut_ref(step)` to inspect
or reuse its state afterward. The example folds through a selected Pipeline
with a borrowed mutable reference, then prints its next weight, `4`.

Named shared `Binary` callbacks remain borrowed and reusable. A moved or
temporary callback uses its mutable receiver when available, otherwise its
shared receiver. This also defines the choice for a callback implementing
both contracts. Consuming-only callbacks are rejected, even for a source
that happens to contain only one element.

Empty initialized folds return the initializer without calling the step.
Uninitialized reductions skip the step for singletons; empty input still
produces Optional absence or the existing empty-reduction error. `fold_until`
stops at the first `Break`. Exact callback errors stop before another pull;
uninitialized `reduce` keeps its existing `ReductionStepError` wrapper.
Move-only inputs, carry, captures and errors are released exactly once.

## Stateful borrowing predicates

`BorrowMutableCallable` stores predicate state in a normal callable struct.
Pass it directly to `filter`, `filter_not`, `take_while`, `drop_while`,
`partition`, `find`, `any`, `all`, or `count_where`, including their fluent
methods. Each operation owns one callback and borrows each candidate;
move-only input values need no copy. A moved or temporary callback prefers
its mutable receiver when it also implements a shared receiver.

Filters, prefixes and partitioning remain lazy and require `Failure = Never`.
Construction does not invoke the predicate. Prefixes retain their boundary
rules, and partitioning still requires an explicit buffer policy. Searches
and counting preserve typed callback errors, including `StopIteration`, and
stop before another source pull on failure. `find`, `any`, and `all` keep
their existing short-circuit and empty-input behavior.

Named shared predicates remain borrowed in searches; named standard predicate
adapters retain their existing reuse in lazy operations. To inspect mutable
state after individual calls, use `invoke_borrowed_repeated[E]` with a named
callback. Move it into an iterator operation with `predicate^` when that
operation should own the state.

## Prefixes, indexed mapping and consuming terminals

<!-- example: docs/examples/iteration_expansion.mojo -->

`drop_while` tests `0`, `1`, `2` and `3`, then stops testing. `take(2)` asks
only for `3` and `4`; `map_with_index` receives `(1, 3)` and `(2, 4)`, yielding
`13` and `24`. Construction runs no callbacks. `zip` yields a flat tuple and
stops at the shortest input; earlier inputs can be pulled before a later input
ends. `chain` concatenates sources with the same element type.

Use `.take_while[predicate]()` and `.drop_while[predicate]()` for native
compile-time thin predicates, or pass a captured or reusable predicate value.
The value-taking forms fuse exhaustion; standard adapters keep
their native exhaustion behavior. `.enumerate(start=0)` and
`.map_with_index(function, start=0)` put the index first. The binary method is
`.zip_with(other, function)`; its free counterpart is
`zip_with(source, other, function)`.

`zip_with` and `map_with_index` can reuse a named two-argument `partial`, shared
binary `flow`/`compose` chain or binary `flip` wrapper. The example binds the
scale once in `project`, uses it for two indexed maps, then moves it into a zip.
Both operands are consumed by the operation; Partial's native target borrows
them during each call. These callbacks must be non-raising, and the indexed
callback's first input must be Int. Custom callables retain their existing
receiver selection and ownership forms.

A named unary `partial` works in `filter`, `filter_not`, `take_while` and
`drop_while`, in free-function and fluent forms. The example reuses
`under_three` to select values and then skip a prefix. These predicates borrow
each candidate, must be non-raising and return Bool. Construction invokes
nothing; the iterator retains a named predicate's borrow until consumption or
abandonment.

On Mojo 1.2, native callbacks that mutate owned captures require
`@always_inline`; this includes stored prefix predicates. Alternatively, use a
library callable with an explicit mutable receiver. See
[native boundaries](../architecture/native-boundaries.md#mojo-12-compatibility).

`first`, `last`, `is_empty`, `count`, `count_where`, `contains` and `for_each`
consume their source. `first`, `is_empty` and a matching `contains` stop early
and destroy the remaining owned source. `count` visits every element.
`for_each` requires a callback returning `NoneType`. A terminal callback's
raised error propagates unchanged, including `StopIteration`.

`to_non_empty_list` explicitly collects into `Optional[NonEmptyList[T]]`.
`combine_all_optional[S=YourSemigroup]()` uses the first element as its seed
and returns `None` on empty input. `collect_fold[M=YourMonoid](function)`
starts from the Monoid's identity and combines only present callback results,
without an intermediate collection. Callback and Monoid failures stop before
another pull; if both can raise, their error types must match.

The example reuses named partials in `count_where`, `for_each` and
`collect_fold`, through free functions and Iter methods. Counting borrows each
candidate; sinks and optional folds consume their input. `for_each` and
`collect_fold` also accept named native adapters and shared compositions.
Empty input calls no callback; `collect_fold` still constructs the Monoid
identity first, and an identity failure destroys the source without pulling it.

## Reuse projections in reductions

<!-- example: docs/examples/reusable_projections.mojo -->

`sum_by`, `fold_map` and `find_map` accept named unary partials, native
adapters and shared compositions through free functions, Iter, Piped and
selected Pipeline methods. These reductions run immediately without building
an intermediate collection; the example reuses `price` across them.

`min_by` and `max_by` borrow each candidate, so a unary `partial` also works
as a reusable key function. An adapter that consumes its argument cannot be
used as a borrowing key. Extrema keep the original element, evaluate each key
once and retain the first element on ties. `find_map` requires an Optional
result and stops at its first present result. Raised errors keep their exact
types; callback and Monoid errors must match when both can raise.

Owned key projections can implement `BorrowMutableCallable` directly:
`min_by(source^, key^)`, `iterated(source^).max_by(key^)`, and the corresponding
Piped and selected Pipeline methods infer the payload and key types. The
non-empty variants accept the same callbacks. A repeated call prefers
`invoke_mut`, retaining one callback state throughout the reduction; a
shared-only key uses `invoke`. Consuming-only keys are rejected. Native callbacks
and named shared adapters retain their existing reuse.

Lazy `pair_with` and `tap_each`, including Iter methods, accept the same owned
shared or mutable borrowing callbacks. They borrow each element once per pull
and retain the original payload without copying it. `pair_with` retains the
projection beside it; `tap_each` discards the projection. Lazy callbacks must
be non-raising. Abandoning an iterator releases its callback and remaining
source; any returned projection keeps its external origins.

`filter_map(callback)` also infers the present Optional payload for library
callables, including a moved callback. It supports named partials, native unary
adapters, shared compositions and compatible shared Kleisli chains. The
example's `quote` needs no output type annotation and is used in two lazy chains.
Only the outer Optional is removed: a present Result error or inner absence is
still a normal output. Lazy callbacks remain non-raising.

Explicit `filter_map[U](...)` and `[U=U]` bindings remain available. Generic
wrappers that express only `F.Out == Optional[U]` pass `[U]` explicitly to
preserve that type evidence through the native compiler.

## Fold scalars, SIMD vectors and documents with one function

<!-- example: docs/examples/generic_fold.mojo -->

`fold_left` returns the accumulator type its step returns. Over `[1, 2, 3]`
with `scalar` it returns `6`, and over an empty list it returns the initial
`7`. Over SIMD vectors, `vector` adds lane by lane and the result is still a
vector, equal to the hand-written loop; no lanes are reduced. Over three words,
`append_word` builds the `Document` `"native functional composition"` with a
word count of 3, the same as the loop in `main`.

## Lazy branches

<!-- example: docs/examples/iteration_branching.mojo -->

`partition(source, predicate, buffer=...)`, `partition_map(source, classify,
buffer=...)` and `unzip(source, buffer=...)` return native tuples of two
move-only iterators. The same methods are available on `Iter`. The policy is
required: `Unbounded()` yields raw values; `BoundedFail(n)` yields
`Result[Value, BufferLimitExceeded]`. Its constructor raises
`BufferCapacityError` for non-positive capacity. Construction never pulls.

`partition` borrows each candidate and routes accepted values first.
`partition_map` consumes candidates into `Result[A,B]` and routes Ok/Err
payloads respectively. A named unary `partial` can be reused in either
operation. `partition_map` also accepts reusable native adapters and shared
compositions. The example uses `evens` for two partitions and `route` for two
classifications. Their branch handles retain a shared callback borrow; keep
the callback alive while any branch may still use it. Both lazy callbacks
remain non-raising.

`unzip` splits native pairs. Each source item is
processed once, in demand order; both outputs of an overflowing pair are
rejected together. Overflow discards all backlog and releases upstream,
then gives each live branch one terminal error before permanent exhaustion.

Use `next(branches[0])` and `next(branches[1])` to interleave consumption.
Calling `.close()` or dropping a handle releases its backlog and stops buffering
for it. The remaining branch continues; dropping or closing both releases the
source and captures without further pulls. Handles retain all source and capture
origins. Access is synchronous and sequential; reentrant or overlapping access
aborts before another mutable borrow. See the [full contract](../architecture/iteration.md#lazy-branching-with-explicit-buffering).

## Alignment

<!-- example: docs/examples/iteration_alignment.mojo -->

`align(left, right)` yields `Ior[A,B]` until both inputs end. Left and Right
identify the input sides; they do not mean failure or success here.
`align_with(left, right, function)` maps each owned Ior, and
`pad_zip(left, right)` yields `(Optional[A], Optional[B])`. The pair always has
at least one present field. Fluent calls are `.align(other)`,
`.align_with(other, function)` and `.pad_zip(other)`.

Pass native callbacks directly, as the example does with `describe`.
`align_with` can also reuse a named unary `partial`, `as_unary` adapter or shared
composition. Each callback receives an owned Ior and may return any
movable value, including Optional or Result
without removing their outer layer.

All three are lazy, preserve each input's current position and use constant
iterator state. Each output pulls each live side at most once, left before
right; an exhausted side stays exhausted. Payloads and callback captures can be
move-only and retain their native origins. `align_with` callbacks cannot raise.
`AlignIterator.bounds()` combines the remaining bounds by taking their maximum;
an unknown upper bound on either live side leaves the combined upper bound
unknown. The mapped forms retain the existing map adapter's conservative bounds.

## Separate carry and output

<!-- example: docs/examples/iteration_scan_map.mojo -->

`scan_map(source, initial, step)` and `.scan_map(step, initial)` apply a step
`(var A, var T) -> Tuple[A,Y]`. The carry `A` and output `Y` are independent;
neither needs to be Copyable. Every pull consumes one source item and invokes
the non-raising step once. Empty input yields nothing, and exhaustion is fused.
The carry stays owned by the iterator until it is destroyed, including early
abandonment through `take`; no final-carry extraction is promised.

A named two-argument partial, shared binary composition or binary `flip`
wrapper can be reused in either form. The example reuses `price` with two
initial totals, then transfers it with `price^`. Ordinary calls infer the
output type from the returned pair; explicit `A`, `T` and `Y` bindings remain
available. The callback borrow follows the [shared lifetime rules](../start/ownership.md#reuse-callbacks-by-name),
while the iterator owns its carry independently.

Use `scan_left` when each accumulator snapshot is an output, including the
initial snapshot. It supports the same named binary callback reuse. The
accumulator must remain `Copyable`: each yielded snapshot is an independent
copy, including the sole snapshot produced for an empty source.
Generic native wrappers preserve `A`, `T`, `Y` and forward them explicitly;
`ScanMapIterator[A,T,Y,I,F]` names the concrete lazy iterator, including origins.

To keep the final carry, use `map_accumulate(source, initial, step)` or
`.map_accumulate(step, initial)`. Inspired by Cats `Traverse.mapAccumulate`,
it returns `(final_carry, List[output])`. It consumes a finite source from its
current position, invoking the step immediately after each pull. Empty input
returns the initial carry and an empty list. Storage grows with the outputs;
the inputs are not collected first.

Ordinary native functions and library callbacks infer the output type. Mutable
library steps run directly, with mutable invocation preferred over shared
invocation; consuming-only callbacks are rejected. Named standard binary
adapters, such as `price` in the example, can be reused. Native closures enter
through `BinarySignature[A,T,Tuple[A,Y],E].capture(callback)`. Aliased thin
pointers select `[Y=Output]`, and `[E=Failure]` for typed errors. Generic library
wrappers forward their selected output with `[Y=Y]`.

The step may raise its exact native error, including `StopIteration`; that is
a failure, not source exhaustion. No subsequent item is pulled. Partial
outputs, remaining owned inputs, carry and callback are released on failure.
Borrowed callback adapters keep their named owner alive for the call, and
borrowed outputs retain their native origins. Use `fp.control.scan` when you
need reverse traversal, length validation or static scheduling.

## Traverse into an effect

`iterated(source).traverse(callback)` infers its target from the complete callback
result: Optional, Result, List, or a recipe declaring its Reader, State or Writer
family. It collects successful payloads into a List inside that effect.
`.traverse_void(callback)` infers the same target and discards successful
payloads without building an output list.

<!-- example: docs/examples/fluent_effects.mojo -->

Result inference selects ordinary fail-fast Result behavior. Choose
`.traverse[ValidationFamily[YourSemigroup]](callback)` explicitly to accumulate
stored errors. A Kleisli chain's declared family takes precedence over its output
carrier for both terminals, including external families and transformer layers.
For example, a `ResultT[Reader[Environment], Failure]` chain keeps its stored-error
short-circuiting even though its underlying carrier is a Reader recipe. Explicit
targets override inference and remain available when the callback has no family
declaration. Existing positional family, callback-type and native-error bindings
keep their order.

Both terminals consume the source from its current position. Callback calls,
short-circuiting and deferred execution follow the selected family: Reader and
State pull nothing until `run`. Native errors and borrowed origins are retained;
move-only payloads need no copy unless the target family's branching requires it.
Shared and mutable library callbacks can be moved into either terminal. A named
Kleisli chain or function composition can be reused by both `traverse` and
`traverse_void`; each borrows its shared callable view. Callbacks must support
repeated invocation. Native function names and captured callbacks retain their existing
admission rules. Stored `def(...) thin -> Effect` pointers also work directly,
with inferred or explicit targets. Traversal copies the pointer into its owned
callback, so a deferred recipe does not borrow the caller's pointer variable.
Input values, outputs and errors retain their native ownership and origins.

A generic wrapper whose thin pointer has an opaque calling convention can pass
`as_unary(function)` to either terminal. That existing factory admits the pointer
once and supplies the library callable contract. Ordinary concrete pointer calls
need no adapter; explicit type bindings on existing closure and callable
overloads retain their meaning.

## Observe effects and retain the elements

For a library borrowing callable, `.traverse_tap(observer)` infers its target
from the callable's complete `Result` metadata. Each invocation borrows an
element; successful observation retains that original element in the collected
List. Failure, branching and deferred execution follow the selected family.
Move-only elements need no copy unless that family's branching requires one.

An owned observer is consumed. Pass `shared_ref(observer)` or
`mut_ref(observer)` to retain a named callable, keeping it alive until a deferred
result finishes. The native callback example uses the existing BorrowSignature
adapter and shares it for the traversal:

<!-- example: docs/examples/native_callback_reuse.mojo -->

Raw native callbacks retain `.traverse_tap[Family](callback)` and their existing
explicit bindings. A `BorrowSignature[Input, Output, Error].capture(callback)`
adapter supplies the same typed borrowing contract and can use inferred target
selection. The [native boundary record](../architecture/native-boundaries.md#mojo-12-compatibility)
explains the compiler limit on unselected native error inference.

## Filter with effects

For a borrowing callable, `iterated(values^).filter_effect(predicate)` infers
its target from the complete `Result` metadata. The target's payload must be
Bool. Successful True results retain their original elements; False results
discard them and continue. An absent Optional or stored Result error is a
failure of the target effect, following that family's failure policy.

Pass native predicates directly with `.filter_effect[Family](function)`, as in
the example below. `BorrowSignature[Input, EffectOfBool, Error].capture` supplies
a borrowing callable contract when inferred target selection is useful.
Named mutable predicates can be reused with `mut_ref(predicate)`.
Linear targets retain move-only inputs; branching targets keep their existing
copy requirements. Explicit Validation and third-party families remain supported.

Postprocessing stays inside the effect. Reader and State defer both filtering
and callback errors until execution. The same distinction between construction
and execution applies to `traverse_filter` and `flat_traverse`, through Iter,
free functions and Piped. A construction-error selector does not change a
stored deferred computation's execution error.

<!-- example: docs/examples/traversal_composition.mojo -->

## Flatten or select effectful results

For a repeatable library unary callable, `iterated(values^).flat_traverse(function)` infers
the target from its complete output type and flattens the successful List
payloads. `traverse_filter(function)` collects present Optional payloads instead.
An absent inner Optional skips one result; an absent outer Optional or a stored
Result error follows the target's failure policy.

Use `as_unary(function)` to supply the same contract for a native callback, or
retain explicit `.flat_traverse[Family](function)` and
`.traverse_filter[Family](function)` calls. An owned callable is consumed;
`shared_ref(function)` and `mut_ref(function)` retain its owner for reuse. Keep
that owner alive until a deferred computation finishes.

Reusable Kleisli chains and shared function compositions can be passed directly:
`.flat_traverse(chain)` and `.traverse_filter(chain)`. These calls borrow the
chain through its existing callable view. The same chain can be reused after
the traversal, and deferred results keep the borrow until execution finishes.
A Kleisli chain's selected family remains authoritative, including custom
policies whose carriers also look like native Optional or Result values.
An explicit family argument still overrides target inference.

Both terminals consume the iterator from its current position. Empty input
lifts an empty List. Reader and State defer traversal and postprocessing until
execution, preserving exact callback errors. Validation and third-party families
remain explicit choices; native Result inference remains fail-fast. Existing
positional and named family/error bindings keep their meaning.

## Sequence existing effects

Use `iterated(effects^).sequence()` when the elements are already effects.
The complete element type selects the target, just as the callback result does
for `traverse`. `sequence_void()` discards successful payloads; `flat_sequence()`
flattens List payloads; `sequence_filter()` collects present Optional payloads.
An absent outer Optional or a stored Result failure remains an effect failure.
Empty input lifts the corresponding empty output into the inferred family.

<!-- example: docs/examples/traversal_composition.mojo -->

All four consume the iterator from its current position. Reader and State still
wait until `run` to pull it. Validation, external families and erased transformer
layers remain explicit: for example, `.sequence[ValidationFamily[Errors]]()`.
Existing positional and named family/error arguments keep their meaning.

## Effectful search and reduction

<!-- example: docs/examples/iteration_effect_search.mojo -->

| Operation | Callback or input | Result |
|---|---|---|
| `find_effect[G](source, predicate)` | Borrowed element → `G[Bool]` | `G[Optional[element]]` |
| `find_map_effect[G](source, function)` | Owned element → `G[Optional[B]]` | `G[Optional[B]]` |
| `fold_map_effect[G, M](source, function)` | Owned element → `G[M.Value]` | `G[M.Value]` |
| `sequence_filter[G](source)` | Elements already contain `G[Optional[B]]` | Effect containing present values |

The first three are consuming Monad terminals, also available on `Iter` and
`Piped`. Searches stop each live branch at its first match. Empty input and a
successful search with no match lift `None`; an absent or failed outer effect
still represents effect failure. List branches retain their first match while
other branches continue. Existing family copying requirements still apply:
branching searches cannot retain move-only values when the family must copy.

`fold_map_effect` combines values in source order with the explicit Monoid.
It constructs `M.empty()` before binding the source, even for Reader or State.
Callbacks and combinations run according to the selected family's timing;
Reader and State defer them until `run`. Empty input lifts the identity.
Stored failures stop the relevant effect; native callback, monoid and family
errors propagate unchanged and must share an admitted native error type.
Generic native wrappers can name exact errors with `E=` and `X=` and must
forward the payload and family admission constraints.

`sequence_filter` is identity `traverse_filter`, with the same Applicative and
source-shape support. Free and `Iter` forms collect present values into a List
inside the effect; `Piped` follows the source family's traversal shape. It is a
terminal traversal, so it consumes the successful input rather than returning
a lazy filtered iterator. All four preserve current iterator position, native
ownership and borrowed origins.
