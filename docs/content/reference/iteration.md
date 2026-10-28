# fp.iteration

`fp.iteration` provides lazy mapping, filtering and scans, together with folds,
reductions and searches over native iterators and owned collections. The
[iteration tutorial](../tutorial/iteration.md) follows values through a lazy
chain and shows how a terminal operation consumes them.

<!-- api: iteration -->

## Prefixes, indexed mapping and consuming terminals

<!-- example: docs/examples/iteration_expansion.mojo -->

`drop_while` tests `0`, `1`, `2` and `3`, then stops testing. `take(2)` asks
only for `3` and `4`; `map_with_index` receives `(1, 3)` and `(2, 4)`, yielding
`13` and `24`. Construction runs no callbacks. `zip` yields a flat tuple and
stops at the shortest input; earlier inputs can be pulled before a later input
ends. `chain` concatenates sources with the same element type.

Use `.take_while[predicate]()` and `.drop_while[predicate]()` for native
compile-time thin predicates, or pass a callback value for an owned captured
predicate. The value-taking forms fuse exhaustion; standard adapters keep
their native exhaustion behavior. `.enumerate(start=0)` and
`.map_with_index(function, start=0)` put the index first. The binary method is
`.zip_with(other, function)`; its free counterpart is
`zip_with(function, source, other)`.

A named unary `partial` can be reused in `filter`, `filter_not`, `take_while`
and `drop_while`, in either free-function or fluent form. The example reuses
`under_three` to select values and then skip a prefix. These iterators borrow
the partial until consumed or discarded. Use `predicate^` or a temporary
partial to transfer its stored prefix to the iterator. Construction copies
nothing from an existing predicate and invokes nothing; each actual native
call retains `partial`'s documented bound-argument copies. Lazy predicates
still must be non-raising and return Bool.

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

A named unary `partial` can be reused in `count_where`, `for_each` and
`collect_fold`, through either the free functions or Iter methods. The example
reuses `under_three` for counting, `evens` for optional folds, and `show` as a
sink. Counting borrows each candidate; sinks and optional folds consume their
input. `for_each` and `collect_fold` also borrow named native adapters and
shared compositions. Callback reuse introduces no capture copy; Partial's
normal bound-argument copies still occur on each native invocation.

These operations complete before releasing the callback borrow. Explicit
`callback^` arguments transfer ownership. Empty input calls no callback;
`collect_fold` still constructs the Monoid identity first, and an identity
failure destroys the source without pulling it.

## Reuse projections in reductions

<!-- example: docs/examples/reusable_projections.mojo -->

Pass a named unary `partial`, `as_unary` adapter or shared `flow`/`compose`
chain directly to `sum_by`, `fold_map` or `find_map`. Free functions and
`Iter`, `Piped` and selected `Pipeline` methods borrow the callback for the
reduction; it can be used again afterward. Passing `callback^` still transfers
ownership. No callback copies or new intermediate collections are introduced.

`min_by` and `max_by` borrow each candidate, so a unary `partial` also works
as a reusable key function. An adapter that consumes its argument cannot be
used as a borrowing key. Extrema keep the original element, evaluate each key
once and retain the first element on ties. `find_map` requires an Optional
result and stops at its first present result. Raised errors keep their exact
types; callback and Monoid errors must match when both can raise.

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

`partition(predicate, source, buffer=...)`, `partition_map(classify, source,
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
the callback alive while a branch may still use it. Passing `callback^` or a
temporary transfers ownership. Both lazy callbacks remain non-raising.

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
`align_with(function, left, right)` maps each owned Ior, and
`pad_zip(left, right)` yields `(Optional[A], Optional[B])`. The pair always has
at least one present field. Fluent calls are `.align(other)`,
`.align_with(other, function)` and `.pad_zip(other)`.

All three are lazy, preserve each input's current position and use constant
iterator state. Each output pulls each live side at most once, left before
right; an exhausted side stays exhausted. Payloads and callback captures can be
move-only and retain their native origins. `align_with` callbacks cannot raise.
`AlignIterator.bounds()` combines the remaining bounds by taking their maximum;
an unknown upper bound on either live side leaves the combined upper bound
unknown. The mapped forms retain the existing map adapter's conservative bounds.

## Separate carry and output

<!-- example: docs/examples/iteration_scan_map.mojo -->

`scan_map(step, initial, source)` and `.scan_map(step, initial)` consume a step
`(var A, var T) -> Tuple[A,Y]`. The carry `A` and output `Y` are independent;
neither needs to be Copyable. Every pull consumes one source item and invokes
the non-raising step once. Empty input yields nothing, and exhaustion is fused.
The carry stays owned by the iterator until it is destroyed, including early
abandonment through `take`; no final-carry extraction is promised.

Use `scan_left` when each accumulator snapshot is an output, including the
initial snapshot. Use `fp.control.scan` for eager finite scans that return the
final carry and collected outputs. Its native errors and scheduling are unchanged.
Generic native wrappers preserve `A`, `T`, `Y` and forward them explicitly;
`ScanMapIterator[A,T,Y,I,F]` names the concrete lazy iterator, including origins.

## Effectful search and reduction

<!-- example: docs/examples/iteration_effect_search.mojo -->

| Operation | Callback or input | Result |
|---|---|---|
| `find_effect[G](predicate, source)` | Borrowed element → `G[Bool]` | `G[Optional[element]]` |
| `find_map_effect[G](function, source)` | Owned element → `G[Optional[B]]` | `G[Optional[B]]` |
| `fold_map_effect[G, M](function, source)` | Owned element → `G[M.Value]` | `G[M.Value]` |
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
