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
payloads respectively. `unzip` splits native pairs. Each source item is
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
