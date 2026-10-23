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
