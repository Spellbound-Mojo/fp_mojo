# Iteration

`fp.iteration` adds the folds, lazy adapters and terminal operations that Mojo's
standard library does not provide, on top of Mojo's own iterator protocol. It
never introduces a second iterator protocol: every adapter is a native
`Iterator`, and advancement raises only `StopIteration`.

## Native first

| Capability | Source | Why |
|---|---|---|
| `Iterator`, `Iterable`, `IterableOwned`, `iter`, `next` | `std.iter` | The protocol itself |
| `chain`, `zip`, `enumerate`, `empty`, `once`, `peekable` | `std.iter` | Standard adapters, imported directly |
| `take`, `drop`, `take_while`, `drop_while`, `cycle`, `product` | `std.itertools` | Standard adapters with their own copy constraints |
| Truth-value `any`/`all` over borrowed iterables and SIMD lanes | `std` | Kept canonical; not reimplemented |
| `List(iterable)` | `std.collections` | Collection from copyable elements |
| `map` | `fp.iteration` | `std.iter.map` takes a compile-time thin function and requires a copyable output; the library adds move-only outputs, captured callbacks and library callables |
| `filter`, `filter_map`, `flatten`, `flat_map`, `scan_left` | `fp.iteration` | No lazy standard equivalent |
| `find`, predicate `any`/`all` | `fp.iteration` | Standard forms take no predicate and do not consume a move-only iterator |
| `collect_list` | `fp.iteration` | `List(iterable)` requires copyable elements and does not consume a single-pass iterator |
| `fold_left`, `reduce`, `reduce_optional`, `fold_until` | `fp.iteration` | No standard fold |
| `collect_results` | `fp.data` | The library `Result` has no standard aggregation |

A source is a native iterator or an owned collection. `_advance._Source[S]` and
`_source(s)` are the single rule: an iterator is used as it is, and only a value
that is not an iterator is consumed through its `IterableOwned` iterator, so a
value that is both is never restarted. `flatten` applies the same rule to inner
values. Every public entry point takes its source through them.

Each library operation replaces itself with the standard one when Mojo provides
the same ownership, pull order and error contract. Standard adapters keep their
own semantics: `zip` may pull an earlier input before noticing a later one is
exhausted, `take(…, 0)` does not pull, and `take_while` consumes the first
rejected element.

## Folds

```text
fold_left(step, initial, iterator) -> A       step: (A, T) -> A
fold_until(step, initial, iterator) -> ControlFlow[B, A]
reduce(step, iterator[, initial]) -> A or T
reduce_optional(step, iterator) -> Optional[T]
```

- Evaluation is sequential, left to right, one `step` call per consumed
  element. The algorithm never reassociates, parallelizes, vector-reduces or
  tree-reduces.
- `A` and `T` may differ. Nothing requires arithmetic, a numeric zero,
  associativity or a scalar element. Move-only accumulators are supported.
- `fold_until` returns `Break(result)` immediately, without pulling another
  element. Normal exhaustion returns `Continue(final_accumulator)`.

Reduction without an initial value follows Python's model:

| Input | Initial value | Result and calls |
|---|---|---|
| Empty | Given | The initial value; no calls |
| `n` elements | Given | `n` calls |
| Empty | Omitted | `EmptyReductionError` (`reduce`) or absence (`reduce_optional`) |
| One element | Omitted | That element; no calls |
| `n > 1` elements | Omitted | The first element seeds the fold; `n − 1` calls |

The omitted initial value is a separate overload, never a sentinel such as
`None`. Without an initial value the accumulator type is the element type; a
type-changing reduction supplies an initial value.

A raising uninitialized `reduce` needs to report two different failures, so it
raises `ReductionError[E]`, a `Variant` of `EmptyReductionError` and
`ReductionStepError[E]`. A step that itself raises `EmptyReductionError` still
lands in the step alternative. `reduce_optional` turns only empty input into
absence; a failing step still raises.

## Lazy adapters

| Adapter | Callback | Pulls per output |
|---|---|---|
| `map` | owned element → value | One |
| `filter` | borrowed element → `Bool` | As many as needed to find a match |
| `filter_map` | owned element → `Optional[U]` | As many as needed to find a present value |
| `flatten` | none | Exhausts each inner source before the next outer element |
| `flat_map` | owned element → iterator or owned iterable | `map` followed by `flatten` |
| `scan_left` | owned accumulator and element → accumulator | The initial snapshot first, then one per element |

The pull rules:

1. **Construction is inert.** Creating an adapter does not pull, and does not
   call the callback. Moving the callback and source into the adapter is the
   only construction work.
2. **No speculative pulls.** Each output pulls only what it needs to produce
   that output or detect exhaustion.
3. **Fused exhaustion.** Once a source reports exhaustion, the adapter never
   pulls it again (`iteration._advance._next_fused`).
4. **No caching.** Laziness does not add replay, multiple traversal or safety
   on infinite input; an adapter has the traversal capability of its source.
5. **Origins stay attached.** An adapter over a borrowed collection carries the
   collection's origin, and a flattened iterator cannot outlive the inner owner
   it yields from.

Abandoning an adapter destroys its owned state without evaluating the rest.

`scan_left` is the one operation that copies: after yielding a snapshot it must
keep the accumulator, so it requires `Copyable` and yields `n + 1` independent
snapshots for `n` inputs. The initial snapshot is yielded before the first pull.
This copy requirement belongs to the scan and is not imposed on folds.

`filter` borrows each candidate and yields the original value, so the predicate
cannot consume a value that must then be yielded. `filter_map` consumes each
candidate and skips only `None`; a present `Result.Err` is an ordinary output.
`flat_map` keeps the returned inner iterator or iterable until it is exhausted or
abandoned.

### Callbacks in lazy adapters

Mojo's `Iterator.__next__` can raise only `StopIteration`, so a lazy callback
cannot raise anything else without ambiguity. Lazy callbacks are therefore
non-raising. To carry a domain failure through a lazy pipeline, yield `Result`
elements and aggregate them with `collect_results`, which stops at the first
`Err`.

An adapter stores the caller's concrete callback value, with its captures and
origins, under ordinary value constraints, and checks callable conformance when
it applies the callback. Constraining a struct parameter to a function-type
trait directly would make its methods capturing, which conflicts with the
iterator protocol's effects.

The adapter calls a stored native callback through mutable access to itself.
On Mojo 1.1, calling a closure with owned mutable state through a read borrow
can lose updates at O3; mutable access avoids that shape.

Accepted callbacks are plain functions, capturing closures (move them in with
`callback^` when they own non-trivial state) and, for the owned-argument
adapters, shared-receiver `Unary`/`Binary` values such as `Partial`.

### Generic return types

Generic helpers that return an adapter name its type with `MapIterator[T, U, I, F]`,
`ScanIterator[A, T, I, F]`, `FilterIterator[T, I, F]`,
`FilterMapIterator[T, U, I, F]` or `FlatMapIterator[T, U, I, F]`. These are
aliases of the implementation types, adding no storage. `I` is the source's
native iterator type: the iterator itself, or the owned iterator of a consumed
collection. Their `F` defaults to the exact thin callback signature. The working spelling is:
`I: Iterator`, the native callback signature for `F`, and `where I.Element == T`.
Advancement asserts `I.Element == T` nominally before transferring an element,
so two element structs with identical layouts are never confused.

For captured `flat_map`, the check that the callback returns a native iterator
or iterable is a compile-time assertion inside the factory rather than a `where`
clause. The `where` form relies on callback metadata (`F.T`, `F.U`) that Mojo 1.1
does not expose through a precompiled package.

## Terminal driver

Every terminal operation (`fold_left`, `fold_until`, `reduce`,
`reduce_optional`, `collect_list`, `find`, `any`, `all`) runs one consuming loop,
`iteration._terminal`. Each operation adapts its step to `ControlFlow`:

- ordinary folds never break (their `Break` payload is uninhabited);
- `find` breaks with the accepted original element;
- `any` and `all` break with their deciding value.

`iteration._advance._next_optional` separates source exhaustion from step
failure. It returns an absent outer `Optional` only when the source raises
`StopIteration`; a present element that is itself an empty `Optional` is still
present. The callback runs outside that boundary, so a callback that raises
`StopIteration` propagates as a callback failure instead of ending the loop.
After initialization only the driver advances the source; `Break` or a failure
returns before another pull. Native ownership cleans up the unconsumed tail, the
current accumulator and the pulled value on every exit.

The driver reaches the callback through a typed `Pointer` that carries the
owner's origin. This keeps the callback's address identity without changing its
calling convention, which matters on Mojo 1.1: routing a callback through an
implicit read intermediary loses owned-capture writes at O3, while passing it as
a `ref` argument corrupts some captured layouts at O0.

## Errors

Pure and raising callbacks have separate overloads, and a raising terminal
propagates the callback's exact error type. Inside a generic wrapper, pass
`E=E` explicitly at every call, including calls to another wrapper; do not read
`F.E` from the callback type, because Mojo 1.1 does not reliably expose that
attribute through a precompiled package.

An error or early stop consumes the prefix already read. Source position and
callback side effects are not rolled back.

## Deliberate exclusions

- No right fold over forward-only streams, since it would need an unstated
  buffering contract.
- No reassociated, parallel, horizontally vectorized or tree reduction. SIMD
  accumulators are folded lane-wise as values; lanes are never reduced
  implicitly.
- No raising lazy callbacks (see above).
