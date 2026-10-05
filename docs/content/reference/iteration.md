# fp.iteration

You need `fp.iteration` to transform, filter or fold the values of a native
iterator or collection without writing the loop yourself. The
[iteration tutorial](../tutorial/iteration.md) shows when lazy adapters pull
values and how to choose a terminal operation.

<!-- api: iteration -->

## Fold scalars, SIMD vectors and documents with one function

<!-- example: docs/examples/generic_fold.mojo -->

`fold_left` returns the accumulator type its step returns. Over `[1, 2, 3]`
with `scalar` it returns `6`, and over an empty list it returns the initial
`7`. Over SIMD vectors, `vector` adds lane by lane and the result is still a
vector, equal to the hand-written loop; no lanes are reduced. Over three words,
`append_word` builds the `Document` `"native functional composition"` with a
word count of 3, the same as the loop in `main`.
