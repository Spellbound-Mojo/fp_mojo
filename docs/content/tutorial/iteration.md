# 2. Folds and lazy iteration

`map`, `filter`, `scan_left` and the other adapters in `fp.iteration` build lazy
iterators: nothing runs until you pull a value, and each pull runs only the
callbacks that value needs. Folds such as `fold_left` pull every value and
return one result. Lazy callbacks cannot raise; a failure inside a lazy chain
travels as a `Result` element.

## Build a lazy chain and collect it

This program keeps the positive values of `[-1, 1, 3]`, doubles them and
records running totals. Captured counters show when each callback runs. A
second chain filters `Optional` results and expands each remaining value into a
`List`, and the end of the program shows an order-sensitive fold and an empty
reduction.

<!-- example: docs/examples/iteration.mojo -->

`filter(positive, values^)` consumes the list as its source. A range such as
`range(1, 4)` is already an iterator, and `iter(values)` would borrow the list
instead.

Creating `filter`, `map` and `scan_left` pulls nothing, so all three counters
are still `0` afterwards. `collect_list` then pulls every snapshot:

1. The first snapshot is a copy of the initial `0`, before any input is pulled.
2. The next pull skips `-1`, doubles `1`, and yields `2`.
3. The last pull doubles `3` to `6` and yields the total `8`.

Collecting makes three predicate calls, two map calls and two scan steps, and
the program prints `0`, `2` and `8`. If a consumer abandons the chain early,
native cleanup destroys the current adapter state and the rest of the owned
source; the tail is never evaluated.

The second chain makes three `odd` calls on `range(1, 4)` and two `pair`
expansions, and yields `[1, 11, 3, 13]`.

## Choose the terminal operation

| Need | Operation | Empty input |
|---|---|---|
| A known initial accumulator | `fold_left` or initialized `reduce` | Returns the initializer |
| Same input/accumulator type, no initializer | `reduce` | Raises a distinct empty-reduction error |
| Absence instead of an empty error | `reduce_optional` | Returns native Optional absence |
| Explicit early termination | `fold_until` | Returns `Continue(initial)` |

`fold_left(subtract, 10, range(1, 4))` computes `((10 - 1) - 2) - 3 = 4`. Folds
run in order: they do not reassociate operations, assume numeric types, or
reduce SIMD lanes for you. `reduce_optional(add, range(0))` returns an empty
`Optional`.

`find`, `any` and `all` stop at the first result that decides the answer.
`fold_until` stops on `Break`, with no extra pull from the source. Lazy
`flatten` handles empty inner iterators, and exhausts an inner source before it
pulls the next outer value.

## Know what snapshots and errors cost

For `n` input values, a fully consumed scan yields `n + 1` snapshots. Each one
is a copy of the accumulator, made with its native `Copyable` implementation,
so keeping every snapshot of a growing `List` can cost much more than a
terminal fold. Only the accumulator needs to be copyable; source elements can
move.

Callbacks in lazy adapters cannot raise. To report a failure from inside a lazy
chain, return `Result` elements and finish with `collect_results`. Terminal
folds and searches have separate raising overloads, and a callback's error is
never mistaken for the end of the iterator.

## Return adapters from generic functions

Use `MapIterator` and `ScanIterator` in return annotations, and build their
values with `map` and `scan_left`. The helper receives a native iterator that
is already typed; its `I` includes any source origin. Keeping the exact `F`
preserves captured state and native callback origins across the return.

<!-- example: docs/examples/iteration_generic.mojo -->

`mapped` and `scanned` name their element, result and source types, and call
sites infer them; nothing is discovered at run time. After construction both
counters are `0`. The first `next` returns the initial snapshot `0` without
pulling from the source. The next two return `2` and `6`, after two map calls
and two scan steps. The program then drops the iterator, so the third value is
never mapped, and the borrowed list is still `[1, 2, 3]`. Keep borrowed sources
and the owners of captured state alive and unmoved while the iterator is in
use.

On the pinned compiler, keep the `T`/`U` and `A`/`T` callback parameter names
and the minimal constraints shown here. Separate wrappers compose at a concrete
call site, but a single generic factory that combines a map and a scan loses
callback metadata on Mojo 1.1, so keep them in separate wrappers. See
[native Mojo boundaries](../architecture/native-boundaries.md#generic-code).

## Return filtering adapters

This generic chain keeps the positive values of `[0, 1, 2, 3, 4, 5]`, turns the
even ones into `String` labels, and expands each label into two outputs. Each
helper returns an ordinary lazy adapter with its exact native type and origins.
The flat-map factory checks the inner iterator's conformance at compile time,
after type inference; the helpers do not inspect callback metadata.

<!-- example: docs/examples/iteration_filtering_generic.mojo -->

Construction calls none of the callbacks. Reading `"2"` and `"2!"` pulls the
source up to `2`: three predicate calls, two label calls and one expansion.
Reading `"4"` pulls up to `4` and leaves both the second output `"4!"` and the
source value `5` unevaluated. Dropping the adapter releases its current inner
state and remaining owned values without evaluating them, and the borrowed
source stays available.

- `FilterIterator` yields the original value it selected.
- `FilterMapIterator` skips only absent `Optional` results; a present
  `Result` holding `Err` is still an output.
- `FlatMapIterator` keeps the returned inner iterator's origins and ownership
  until that inner iterator is exhausted or abandoned.

See [native Mojo boundaries](../architecture/native-boundaries.md#generic-code)
for the constraints behind this spelling.

## Generic terminal calls

A terminal wrapper consumes an explicit iterator and borrows the callback. Its
raising signature names `E`, and each forwarding call passes `[E=E]`;
accumulator and element types are still inferred. These native signatures keep
the error type through precompiled imports, with no result cast or callable
promotion.

<!-- example: docs/examples/terminal_generic.mojo -->

`forwarded(append, String("entries:"), range(3))` returns `"entries:012"` after
three calls. Over `[4, -7, 9]`, `append` raises `InvalidEntry(-7)` on the
second value. That exact error crosses both wrappers, and `9` is never pulled,
so the call count ends at five. `find(even, range(3, 8))` returns `4`.

Use the pure overload when the callback does not raise. The same forwarding rule
applies to `reduce_optional`, both `reduce` forms, `fold_until`, `find`, `any`
and `all`.

Next, keep success and failure as values with
[Result transformations](results.md). For every operation, see
[fp.iteration](../reference/iteration.md) and
[ControlFlow](../reference/data.md#ControlFlow).
