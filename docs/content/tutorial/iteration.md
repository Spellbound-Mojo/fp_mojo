# 2. Folds and lazy iteration

This program keeps positive values, doubles them, and records running totals. Captured callbacks count filtering, mapping and scan steps without changing the lazy pull order. A second chain filters Optional outputs and expands each remaining value into an inner List. It also demonstrates an empty reduction and an order-sensitive fold.

<!-- example: docs/examples/iteration.mojo -->

## Follow the pulls

`filter(positive, values^)` consumes the list as its source; a range such as `range(1, 4)` is already an iterator, and `iter(values)` would borrow the list instead. Creating `filter`, `map`, and `scan_left` pulls nothing from the source. The first requested scan value is a copy of the initial `0`, before any input is pulled. The next scan request skips `-1`, doubles `1`, and yields `2`. The final input `3` becomes `6`, producing the total `8`.

`collect_list` explicitly requests all snapshots and materializes a standard List. Until collection, the adapter chain is lazy. If a consumer abandons it early, native cleanup destroys the current adapter state and remaining owned source; there is no forced evaluation of the tail.

## Choose the terminal operation

| Need | Operation | Empty input |
|---|---|---|
| A known initial accumulator | `fold_left` or initialized `reduce` | Returns the initializer |
| Same input/accumulator type, no initializer | `reduce` | Raises a distinct empty-reduction error |
| Absence instead of an empty error | `reduce_optional` | Returns native Optional absence |
| Explicit early termination | `fold_until` | Returns `Continue(initial)` |

The subtraction example computes `((10 - 1) - 2) - 3 = 4`. Folds do not reassociate operations, assume numeric types, or implicitly reduce SIMD lanes.

`find`, `any`, and `all` stop at the first decisive predicate result. `fold_until` stops on `Break`; no extra source pull follows. Lazy `flatten` handles empty inner iterators and exhausts an inner source before pulling another outer value.

## Snapshot and error costs

For `n` input values, a fully consumed scan yields `n + 1` snapshots. Every yielded accumulator is copied according to its native Copyable implementation. Retaining every growing List snapshot can therefore cost much more than a terminal fold. Only the accumulator needs to be copyable; source elements can move.

The filter, map and scan callbacks capture mutable borrowed counters. Construction leaves the counters at zero; collection makes three predicate calls, two map calls and two scan steps. The second chain makes three Optional-filtering calls and two expansions, yielding `[1, 11, 3, 13]`. All lazy callbacks are non-raising. For lazy domain failures, return explicit Result elements and finish with `collect_results`. Terminal folds and searches have separate native raising overloads; callback errors are not mistaken for iterator exhaustion.

References: [fp.iteration](../reference/iteration.md) and [ControlFlow](../reference/data.md#ControlFlow). Next, learn [Result transformations](results.md).

## Return adapters from generic functions

Use `MapIterator` and `ScanIterator` for return annotations, and construct their values with `map` and `scan_left`. The helper receives an already typed native iterator; its `I` includes any source origin. Keeping the exact `F` preserves captured state and native callback origins across the return.

<!-- example: docs/examples/iteration_generic.mojo -->

The wrapper names its element, result and source types explicitly; call sites infer these parameters. There is no runtime type discovery. Construction is inert, and the first scan snapshot still precedes the first source pull. The example stops after two inputs and leaves the borrowed List intact. Keep borrowed source and capture owners alive and unmoved through use.

Use the shown `T`/`U` and `A`/`T` callback parameters and minimal constraints on the pinned compiler. Separate wrappers compose at a concrete call site. A single generic factory that combines heterogeneous map and scan loses callback metadata on Mojo 1.1, so keep them in separate wrappers. See [native Mojo boundaries](../architecture/native-boundaries.md#generic-code).

## Return filtering adapters

This generic chain selects positive inputs, keeps even inputs as String labels, and expands each label into two outputs. It returns ordinary lazy adapters with their exact native types and origins. The helpers retain concrete source and callback types. The flat-map factory checks native inner conformance at compile time after type inference; the helpers do not need to inspect callback metadata.

<!-- example: docs/examples/iteration_filtering_generic.mojo -->

Construction calls none of the callbacks. Reading `2` and `2!` pulls only through source value 2 and expands once. Reading `4` reaches source value 4 and leaves both its second inner output and source value 5 unevaluated. Dropping the adapter releases its current inner state and remaining owned values without evaluating them. The borrowed source stays available.

`FilterIterator` preserves the selected original value; `FilterMapIterator` skips only absent Optional results. A present `Result.Err` remains an output. `FlatMapIterator` retains the returned inner's native origins and ownership until that inner is exhausted or abandoned. See [native Mojo boundaries](../architecture/native-boundaries.md#generic-code) for the constraints behind this spelling.

## Generic terminal calls

Terminal wrappers consume an explicit iterator and borrow the callback. The
raising signature names E, and each forwarding call supplies `[E=E]`; accumulator
and element types continue to be inferred. The existing native signatures
preserve this evidence through precompiled imports. No result cast or
callable promotion is needed.

<!-- example: docs/examples/terminal_generic.mojo -->

The callback stops at the first invalid entry. Its exact `InvalidEntry` error
crosses both wrappers, and the later value is not pulled. Use the pure overload
when the callback does not raise. The same forwarding rule applies to
`reduce_optional`, both `reduce` forms, `fold_until`, `find`, `any` and `all`.
