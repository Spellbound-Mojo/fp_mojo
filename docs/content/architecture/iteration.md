# Iteration

`fp.iteration` implements folds, lazy adapters and terminal operations using
Mojo's iterator protocol. Every adapter is a native `Iterator`, whose
advancement raises only `StopIteration`. The package adds operations and
ownership forms that are missing from the standard library.

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

## Method chains

`iterated(source)` applies the same source rule and stores the resulting native
iterator in `Iter[I]`. The wrapper has one field and no independent traversal
state. Its `__next__` and `bounds` methods delegate to that field.
Its consuming `__iter__` returns itself, preserving its current position even
when the underlying type's own `__iter__` would restart.

Transforming methods consume the wrapper, pass its field to the existing free
factory, and wrap the resulting adapter. Terminal methods pass the field to the
existing terminal. The source conversion, callback dispatch, iteration loops,
error handling and cleanup therefore have the same owners as free-function
calls. `collect_list()` delegates to `to_list()`, which calls the free
`collect_list`.

`Iter` conforms to both native `Iterator` and `IterableOwned`. It can enter
standard consuming adapters such as `enumerate`, `zip` and `chain`; their
results can enter `iterated` to regain method syntax. The wrapper introduces
no implicit copying or borrowed `Iterable` conformance. Standard operations
that require those capabilities retain their native requirements.

The stored iterator type keeps its embedded origins. The wrapper's native
`Iterator` boundary yields values, as the existing iteration adapters do;
borrowing sources retain their native copy requirements. The methods' `where`
clauses preserve input, result and origin equality before delegation. Thin
functions, native closures and library callables retain separate admission
signatures, and raising terminal methods forward `E=E` explicitly for generic
precompiled callers.

Wrapping does not fuse an arbitrary source or add a new exhaustion flag.
Lazy transformation adapters retain their existing fused behavior.
Collection methods require deinitializable elements, just as the free
`collect_list` does; this requirement belongs to those methods rather than the
native iterator wrapper.

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

1. **Construction stores the source and callback.** Creating an adapter moves
   them in without pulling a value or calling the callback.
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
can lose updates at O3; mutable access avoids that shape. A separate native
closure lowering defect also affects some combinations of move-only inputs,
move-only output and owned mutable captures, even on direct calls. Mark such
callbacks `@always_inline` on Mojo 1.1, or put mutable state in a library
callable. Iterator ownership tests cover the annotated native form at O0/O3;
see [known compiler defects](native-boundaries.md#known-compiler-defects).
On Mojo 1.2, mark every native callback that mutates an owned capture
`@always_inline`, including borrowing predicates. Mutable access alone does not
avoid the stored-predicate failure. Explicit mutable library callable storage
remains an alternative.

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

On Mojo 1.2, native `fold_until` infers the callback's break payload as `Q`
independently of the requested `B`, then requires `Q == B` in the public
signature. `B` defaults to `Q`, so ordinary calls still infer the type; explicit
`B=` and positional callback type bindings keep working. The fluent method
checks the same relationship and forwards `B`. The shared driver uses `Q`
throughout, with the final result rebound only after the signature constraint
has established equality. This rejects a callback returning a view from a
different origin, including local storage, without changing iteration or
cleanup semantics.

Native terminal folds now infer both callback inputs and its result independently
of the requested accumulator and element types, then require exact equality.
Result origins therefore reach a constraint diagnostic instead of being forced
during overload inference. The existing shared invocation bridges adapt only
equal types; native errors, element moves and cleanup stay unchanged.

Lazy observers store the recovered borrowing signature in the existing optional
cell to retain its destruction witness, including callbacks that return borrowed
views. Their native invocation still has mutable access to owned captures, with
literal no-value signatures handled separately from generic value results.

Plain raising search predicates keep their thin representation, including
explicit `Never`; thin and closure entry points share terminal execution.

## Errors

Non-raising and raising callbacks have separate overloads, and a raising terminal
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

## Iterator expansion

I1 through I6 are implemented. These additions precede fallible-stream work. The source review compares the pinned
Mojo 1.1.0 library with Mojo 1.2.0 and Cats' current source. The reviewed Mojo
1.2.0 iterator modules retain the relevant operations and constraints; this
expansion does not require a compiler upgrade.

Transforming combinators are lazy and return iterators, including combinators
that split one source into several branches. Materialization happens at an
explicit collector such as `to_list`. Folds, searches and effectful terminals
keep their terminal contracts. Buffering needed by multiple consumers is an
explicit policy, not a reason to materialize the source during construction.

The references are Mojo's [iterator protocol and adapters][mojo-iter],
[itertools][mojo-itertools], and the corresponding
[1.2 iterator][mojo-next-iter] and [1.2 itertools][mojo-next-itertools] sources;
Cats' [Foldable][cats-foldable], [Functor][cats-functor],
[Traverse][cats-traverse], [TraverseFilter][cats-traverse-filter] and
[Align][cats-align]. These links pin the reviewed revisions.

### Existing coverage and naming

Cats describes operations over collection families. Its collection instances
include List and LazyList; a consuming Mojo iterator has a different ownership
and replay contract. Use the operation contracts as references without adding a
blanket Monad or Traverse instance for every native iterator.

| Cats operation | Existing iterator spelling |
|---|---|
| `map`, `mapFilter`, `flattenOption` | `map`, `filter_map`, `compact` |
| `filter`, `filterNot`, `flatMap`, `flatten` | `filter`, `filter_not`, `flat_map`, `flatten` |
| `as`, `void`, `tupleLeft`, `tupleRight`, `fproduct` | `fill`, `void`, `tuple_left`, `tuple_right`, `pair_with` |
| `flatTap`, `productL`, `productR` | `flat_tap`, `before`, `followed_by` with the documented iterator branching semantics |
| `collectFirstSome`, `exists`, `forall` | `find_map`, `any`, `all` |
| `foldLeft`, `reduceLeftOption`, `foldMap`, `combineAll` | `fold_left`, `reduce_optional`, `fold_map`, `combine_all` |
| `minimumByOption`, `maximumByOption` | `min_by`, `max_by` |
| `traverse`, `sequence`, `traverseVoid`, `traverseTap` | `traverse`, `sequence`, `traverse_void`, `traverse_tap` |
| `flatTraverse`, `flatSequence`, `traverseFilter`, `filterA` | `flat_traverse`, `flat_sequence`, `traverse_filter`, `filter_effect` |
| `foldM`, `existsM`, `forallM` | `fold_effect`, `any_effect`, `all_effect` |
| `parTraverse`, `parSequence` | `par_traverse`, `par_sequence`; error accumulation, without concurrent execution |

Keep the existing Mojo names. Scala's `collect` means partial-function
filtering; here `filter_map` expresses that behavior with native Optional, while
`collect_list` is materialization. Use Mojo's `enumerate` order `(index, value)`
instead of adding Cats' reversed `zipWithIndex` tuple convention. Existing
`Iterator.nth` already consumes the iterator and returns an Optional; it needs
coverage and documentation, not another implementation named `get`.

### Implementation passes

| Pass | Additions | Execution owner |
|---|---|---|
| I1 (implemented) | Fluent `take`, `drop`, `enumerate`, `zip`, `chain`; compile-time `take_while[predicate]` and `drop_while[predicate]`; derived `zip_with` and `map_with_index` | Native adapters, followed by existing `map` where needed |
| I2 (implemented) | Captured-predicate `take_while`/`drop_while`; consuming `first`, `last`, `is_empty`, `count`, `count_where`, `contains`, `for_each`; terminal `to_non_empty_list`, `combine_all_optional`, `collect_fold` | Shared prefix state and existing callback bridges; existing terminal accumulation, NonEmptyList constructor and Semigroup |
| I3 (implemented) | Lazy `partition`, `partition_map`, `unzip` with required `Unbounded` or `BoundedFail` buffering policy | One shared source owner, branch routing and queue engine; existing Result and tuple extraction |
| I4 (implemented) | `align`, `align_with`, `pad_zip` | One two-source alignment iterator producing the existing Ior carrier |
| I5 (implemented) | Lazy `scan_map` with separate carry and output | Shared carry/output transition with existing scan mechanisms, below control and algebra |
| I6 (implemented) | `find_effect`, `find_map_effect`, `sequence_filter`, `fold_map_effect` | Existing algebra traversal, retention and dependent-fold mechanisms |

All six passes are complete. The effectful terminals reuse existing family
mechanisms; fallible streams remain a separate contract.

### Native adapter forwarding

Fluent native methods consume `Iter` and return another `Iter`. Preserve the
source's current position: `_OwnedSource` calls the canonical `_source` exactly
once, so native factories receive an owned iterable without restarting an
existing iterator. Passing the raw source through `std.iter` could restart an
iterator whose `__iter__` resets its position.

`zip` and `chain` use native parameter packs without an arity cap. Mojo 1.1
cannot map an owned pack into wrapper values or expand a Tuple into a pack.
The private `_native` boundary normalizes each input once, then initializes
the native adapter's tuple fields. This depends on the pinned standard
library's `_ZipIterator` and `_ChainedIterator` layouts. It adds no advancement
loop: native code still owns pull order, bounds, incomplete tuple cleanup and
exhaustion. Every slot is initialized once, construction cannot raise, and
type equality is checked before moving storage. Borrowed origins remain in
the element iterator types. Recheck this boundary when upgrading Mojo.

Native delegation preserves native behavior, including non-positive `take` and
`drop` counts, left-to-right zip pulls and cleanup of an incomplete tuple. It
does not promise fused exhaustion that a standard adapter does not provide.
`take(0)` must not pull. A failed `take_while` predicate consumes that candidate;
`drop_while` yields the first rejected candidate and stops calling the predicate.
`zip_with` derives from zip and map; `map_with_index` derives from enumerate and
map with `(index, value)` argument order. `_Map` has one invocation policy
parameter; the pair policy reuses `callables.products._take_pair` and the native
or library receiver bridges. No additional mapping loop or callback wrapper
is needed. The `ZipWithIterator` and `IndexedMapIterator` aliases retain the
concrete callback and iterator types, including origins.

Native `take_while` and `drop_while` take a compile-time thin predicate. Keep
that form in I1. I2's value-taking predicate forms store a concrete closure or
library borrowing callable, borrow each candidate, and use the existing lazy
callback bridge. The native signature cannot carry that runtime callback state;
`_Prefix` shares one state machine across both operations and all value-taking
overloads. Drop stops testing after its first rejection; take records completion
at its first rejection. These callbacks remain
non-raising. The library-owned adapter records exhaustion once, as other
library lazy adapters do.

`peekable` remains a direct standard operation initially: wrapping it in Iter
would hide its `peek` method, whose pointer is tied to the adapter's buffered
element. Do not add a superficial wrapper that loses that interface. `cycle`
and Cartesian `product` retain the standard iterator-copy constraints; they do
not gain replay by buffering a consumed source. `empty`, `once`, `count` and
`repeat` remain native source constructors. The terminal `Iter.count()` is
distinct from the standard infinite counting source.

### Consuming searches and materialization

All I2 terminals consume the remaining source. `first` delegates to native
`nth(0)`; `is_empty` consumes at most one candidate and destroys it when present.
Neither is a reusable collection query. `last` consumes to exhaustion and
returns Optional; `count` and `count_where` return Int and visit every element.
Do not use a length bound to skip pulls and their observable work. `contains`
borrows each candidate for native equality and stops at the first match.
`for_each` moves each element into its callback and returns NoneType. Predicates
borrow their candidates. Terminal callbacks retain their exact raised error
types and stop before the next pull on failure.

`to_non_empty_list` delegates to collection and the existing checked
`NonEmptyList.from_list`, returning Optional for empty input. It does not expose
an unchecked constructor. `combine_all_optional` uses Semigroup without needing
an empty value: the first element seeds the reduction, empty input gives None,
and later elements combine left to right. `collect_fold` consumes a callback's
Optional monoid values, skips absent values and combines present values through
the existing accumulation policy. Identity runs before the first pull, including
on empty input. An identity, callback or combination failure stops immediately.
A non-raising callback keeps `M.Error`; a raising callback and raising Monoid
must have the same exact error type (either side may be non-raising). A generic
raising native wrapper forwards `E=E`. The implementation uses terminal
accumulation, so callback `StopIteration` remains a failure rather than source
exhaustion. No intermediate collection is built.

### Lazy branching with explicit buffering

I3 returns a native tuple of independently consumed, move-only iterator handles:

```text
source.partition(predicate, buffer=Unbounded())
    -> (accepted_iterator, rejected_iterator)
source.partition_map(classify, buffer=Unbounded())
    -> (ok_iterator, err_iterator)
source.unzip(buffer=Unbounded())
    -> (left_iterator, right_iterator)
```

There is no implicit buffering default. Construction moves the source and
callback into shared state and creates the branch handles, but pulls nothing
and calls no callback. It may allocate the shared state and queue storage. A
pull first drains that branch's queued values. If its queue is empty, it advances
the shared source only until it can yield a value, reach exhaustion, or encounter
the selected policy's failure condition. Values for another live branch enter
that branch's queue in source order. Source exhaustion is recorded once; each
branch finishes only after its own queue drains.

`partition` borrows each candidate for its non-raising predicate and moves the
original into exactly one branch. `partition_map` consumes each candidate into
a non-raising classifier returning `Result[Accepted, Rejected]`; Ok and Err
route their payloads to the first and second branches respectively. This
explicitly treats the classifier's Result as a routing decision. `unzip` moves
each tuple field into its corresponding branch. All three support move-only
payloads, evaluate each source item once, and preserve order within each branch.
Consumers may interleave pulls in either order, and that demand determines when
source and callback side effects occur.

| Explicit policy | Branch element | When another branch falls behind |
|---|---|---|
| `Unbounded()` | `T` | Retain every pending value for each live branch; storage grows with the undelivered backlog |
| `BoundedFail(capacity)` | `Result[T, BufferLimitExceeded]` | Retain at most `capacity` queued values per branch; terminate the shared computation on overflow and report failure to each live branch |

The policy type determines the branch element type at compile time; the capacity
may be a runtime value. Require a positive capacity and validate it when
constructing the policy, before binding that policy to a source. A limit counts queued
elements, not bytes allocated by those elements. There can additionally be one
in-flight source item and its routed outputs while deciding where to send them;
the implementation must not hide a second unbounded staging queue. Values
already handed to consumers are outside the buffer budget.

For bounded failure, drain an existing requested queue before pulling upstream.
An upstream item is pulled and classified once before its destination is known.
If a routed output cannot enter a live sibling's full queue, the entire split
fails: stop and release upstream, discard the in-flight outputs and queued
backlog, and give each still-live branch one terminal Err followed by permanent
exhaustion. For unzip, check admission for both destinations before publishing
either field of the current tuple. Already yielded values remain yielded, and
callback side effects are not rolled back. Each branch gets an equivalent
buffer error describing the blocked branch and capacity; this metadata can be
copied without copying payloads. The error is a buffer failure, not a rejected
partition value or iterator exhaustion.

For example, partitioning `0, 1, 2, 3, 4` by evenness and pulling only the
accepted branch under `BoundedFail(1)` first yields `Ok(0)` and `Ok(2)`, retaining
`1` for the rejected branch. Encountering `3` while seeking the next accepted
value overflows that queue. Both live branches report the terminal buffer error,
the queued `1` is released, and `4` is never pulled. Under `Unbounded`, that same
consumption schedule retains `1` and `3` and yields `4` normally.

Bounded failure fits the native iterator protocol by yielding Result values;
`__next__` still raises only StopIteration. Consumers can use the existing
Result aggregation for failure-aware terminals. This reuses the carrier and
does not introduce a new general fallible-stream protocol. Stored Results in
the input remain ordinary payloads unless the chosen routing operation
explicitly interprets them.

Lossless bounded backpressure needs cooperation from the consumers. Returning
StopIteration when the queue is full would permanently truncate a branch;
blocking inside synchronous `next` can prevent the same thread from ever
advancing its sibling. A future backpressure policy therefore needs a separate
polling or asynchronous interface with distinct item, pending and done states,
plus a way to schedule the branch that can release capacity. It must not be
silently exposed as a native Iterator. Dropping the oldest or newest queued
value would be a lossy policy and is outside the initial two policies.

#### Branch lifetime and shared ownership

Each branch is a move-only handle. Dropping it or explicitly closing it releases
its queued values and tells the shared owner to discard future outputs destined
for that branch. Closing does not drain upstream. The remaining branch can
continue without buffering for its closed sibling; classification still runs
when needed to decide whether an input belongs to the remaining branch. Dropping
both branches releases the source, callback and queues without further pulls.
A live but idle branch still counts as a consumer. A wrapper such as `take`
does not signal abandonment until it releases its underlying branch handle.

Both handles retain the source's and callback's origins. Shared allocation must
not extend borrowed lifetimes, add Copyable to payloads, or create references
into another movable handle. Use native shared ownership where suitable, with
one private mutable state containing the source, queues, branch-liveness flags,
exhaustion/failure state and policy. The existing immutable Node is not a mutable
iterator broker. Reference counting alone also does not make shared mutation
safe: the storage design must enforce exclusive access for each pull or close,
release that access before yielding, and handle reentrant access explicitly.
The initial contract is synchronous, sequential consumption; concurrent pulling
and callback reentry are not supported. Verify this boundary before publishing
independently movable handles rather than relying on unchecked aliasing.

The implementation uses native `ArcPointer` for ownership and `Deque` for FIFO
storage. A private atomic gate guards every mutable broker access. Overlapping
or reentrant pull/close aborts before a second payload borrow; it never blocks
waiting for a consumer on the same thread. The move-only lease releases the
gate on return or StopIteration unwinding, and native origins keep payload
borrows within the lease lifetime. This is a misuse check, not a promise of
concurrent iteration. `close()` is idempotent; a closed handle remains exhausted.
Its small shared allocation stays alive until both handles are destroyed, while
the source and callback are released on exhaustion, failure or the last close.
`BoundedFail` rejects non-positive capacity with typed `BufferCapacityError`.

Routing, queue admission, failure and close behavior have one implementation
shared by partition, partition_map and unzip. Reuse `_source` and the existing
advancement and callback bridges, Result's owned branch extraction, and
`_take_pair`. Queue storage must move elements, provide amortized constant-time
FIFO operations, and release consumed slots; repeatedly removing the first
element of a List would make draining quadratic. Native collection storage and
shared-owner facilities should remain canonical wherever their contracts fit.

There is no general guarantee that a pull completes on infinite input: a
requested partition may never receive a matching value. Unbounded buffering
can grow without limit while searching; bounded failure limits queued element
count but is not a timeout or a bound on callback work.

### Alignment without truncation

`align` pairs positions until both inputs end, producing `Ior[A, B]`. For
`[1, 2]` and `[10]` it yields `Both(1, 10)`, then `Left(2)`. In this operation
Left and Right designate source sides, not diagnostics or failure. It uses the
existing structural carrier without selecting an Ior algebra policy.

One state machine owns both sources and one exhaustion bit per side. Each
output pulls each live side at most once, left before right. Once a side ends,
it is never polled again. Construction pulls nothing; yielded values move into
Ior, and abandonment releases the remaining owners. State is O(1), and there is
no replay or materialization. `align_with` derives through map; `pad_zip`
derives by converting each Ior to `(Optional[A], Optional[B])`, never emitting
an absent/absent pair. These derived operations must reuse Ior's existing owned
field extraction. Defer default-padding `zip_all` until its repeated-default
copy or factory contract is useful enough to add.

### State and effect follow-ups

Cats' `mapAccumulate` returns the final state and a complete output collection.
The lazy operation is named `scan_map`: a non-raising step consumes
`(state, element)` and returns `(new_state, output)`, yielding exactly one output
per input, with no initial output and no accumulator-copy requirement. State
remains owned by the iterator and is destroyed on abandonment. It does not
promise access to a final state from an unfinished or consumed chain.

`scan_left` and `scan_map` share `_ScanDriver`, with a compile-time initial
snapshot policy and a callback invocation policy. The snapshot policy turns
`scan_left`'s updated accumulator into `(carry, copy)`; its initial output still
precedes the first pull. Both use `callables._scan._Carry` to move a carry into
the callback and install the returned pair using `_take_pair`. The same carry
owner serves `fp.control.scan`, below both iteration and control. An empty
Optional slot represents the interval where the callback owns the carry, so
native error unwinding never destroys a moved value twice.

Native callback bridges remain signature-specific: lazy scans own and mutably
call their captures, while control scan borrows its native callback. Control
scan keeps its existing length validation, reversal, unrolling, error wrapping
and non-inlined step boundary. `scan_left` keeps exactly one copy per yielded
snapshot. An eager iterator `map_accumulate` returning
`(final_state, List[output])` remains a separate candidate.

Native scan admission on Mojo 1.2 infers the entire step result before checking
`R == Tuple[A, Y]`. Eager native invocation preserves `R` until the checked
transition into the shared carry/output driver. This keeps distinct external
origins visible and avoids tuple-pack inference inside a native signature.

`sequence_filter` is identity `traverse_filter`. `find_effect` and
`find_map_effect` use the dependent-fold continuation policy and stop on the
first selected success in each admitted branch. Retaining an original value
for `find_effect` uses the existing retention mechanism and its branch-copy
requirements. `fold_map_effect` combines mapped values with an explicit Monoid
inside the selected Monad; callback, monoid and deferred error admission must
be checked together. These terminal conveniences keep the current family
restrictions, deferred timing and distinction between stored and raised errors.
They do not introduce a fallible `Iterator.__next__`.

`_FirstPresent` and `_Combine` now live in `algebra._accumulation`, shared with
pure reductions. `_SearchStep` only invokes the callback; the existing family
fold controls which branches remain live, when to pull, and how to bind.
`_FoldMappedStep` maps the existing `_BindFirst[_AccumulatePair[_Combine[M]]]`
over each produced effect. This moves the accumulator for single-use families
and requires copying only when the family repeats branches.

The monoid identity is constructed before source binding, including for Reader
and State. Callback invocation and combination follow the family's fold timing.
A fallible identity therefore raises at construction; a deferred combination
raises when run. Callback, monoid and family native errors must admit one exact
native type where they share a boundary. Stored errors stay inside the carrier.
Generic native forwarding can provide `E=` and `X=` as exact error evidence;
the admission signature accepts the callback error or the family's construction
error, and the shared invocation boundaries check the actual raised type.
Borrowed errors and stored-error origins remain part of those comparisons.

### Candidates requiring separate storage contracts

Bounded `chunks(size)` is a useful next step toward stream batching: own each
batch in a native List, admit move-only items, reject non-positive sizes before
pulling, and yield a final partial batch. Its implementation pass must settle
runtime size-error handling and whether output guarantees non-emptiness in the
type. Overlapping windows additionally need a copying or lending contract.

Stable `distinct_by` can retain owned keys in a native Set and yield the original
values, using O(number of distinct keys) storage. A key must not borrow from a
candidate that is about to move or be destroyed. Adjacent deduplication needs
only one retained key and is a different operation. Global `group_by` needs
finite materialization; consecutive grouping may encounter an unbounded run.
These operations should state storage growth explicitly before entering the API.

The branching engine makes lazy `span` and `tee` follow-up candidates with the
same explicit buffering policies. Span changes routing after the first rejected
predicate and retains that boundary value in the suffix. Tee duplicates values,
so it additionally needs Copyable elements or explicitly shared payloads;
partition and unzip do not. Replay and memoization require their own retention
and replay-lifetime contracts. Forward-only right folds retain their exclusion.
Scala PartialFunction, Eval and new higher-kinded capability families are not
required to add the proposed iterator conveniences.

### Acceptance checks

Each pass needs source and precompiled-package coverage at O0 and O3, including
generic wrappers. Verify no pulls during construction, exact prefix and zip
pull traces, already-advanced and restarting sources, empty inputs, early drop,
infinite inputs bounded by take, native bounds, and native versus library
exhaustion behavior. Check callback order and counts, nominal types, borrowed
origins, move-only values and captures, drop-once cleanup, and rejection of
raising lazy callbacks. Terminal callback StopIteration must still propagate
as failure. Alignment also needs unequal lengths and exhausted sides that would
produce more values if incorrectly polled again.

Branching checks additionally cover alternating and uneven consumers, pulling
either branch first, callback-once routing, independent moves, borrowed-origin
escape rejection, queue drain after upstream exhaustion, early close, and both
branches being abandoned. Check exact capacity and overflow, atomic admission
of unzip outputs, the per-branch terminal error, cleanup on shared failure,
and that closing one branch releases its buffer budget. Verify no source work
after exhaustion, failure or final close, and no mutable access surviving a
yield. Buffered move-only values must be destroyed exactly once on every path.

Methods delegate to free factories or existing native implementations. New
terminals use `_terminal` or algebra's existing accumulation drivers, without
adding a loop per overload. Core adapters use leaf data modules, including
`data.ior`, rather than package imports that pull in algebra integration. Run
the DAG and leaf-boundary checks alongside targeted tests, then update public
inventory, API documentation and maintained examples for each implemented pass.

[mojo-iter]: https://github.com/modular/modular/blob/c6fa49f712fe15c99d0461ad2baaf2a15cbc58ce/Mojo/stdlib/std/iter/__init__.mojo
[mojo-itertools]: https://github.com/modular/modular/blob/c6fa49f712fe15c99d0461ad2baaf2a15cbc58ce/Mojo/stdlib/std/itertools/itertools.mojo
[mojo-next-iter]: https://github.com/modular/modular/blob/527d069ee11a41ac5320af1f9402db0a66b2b868/Mojo/stdlib/std/iter/__init__.mojo
[mojo-next-itertools]: https://github.com/modular/modular/blob/527d069ee11a41ac5320af1f9402db0a66b2b868/Mojo/stdlib/std/itertools/itertools.mojo

[cats-foldable]: https://github.com/typelevel/cats/blob/813f1bc8e357991caa587149f1a0ff97cd292d08/core/src/main/scala/cats/Foldable.scala
[cats-functor]: https://github.com/typelevel/cats/blob/813f1bc8e357991caa587149f1a0ff97cd292d08/core/src/main/scala/cats/Functor.scala
[cats-traverse]: https://github.com/typelevel/cats/blob/813f1bc8e357991caa587149f1a0ff97cd292d08/core/src/main/scala/cats/Traverse.scala
[cats-traverse-filter]: https://github.com/typelevel/cats/blob/813f1bc8e357991caa587149f1a0ff97cd292d08/core/src/main/scala/cats/TraverseFilter.scala
[cats-align]: https://github.com/typelevel/cats/blob/813f1bc8e357991caa587149f1a0ff97cd292d08/core/src/main/scala/cats/Align.scala
