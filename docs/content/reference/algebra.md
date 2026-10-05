# fp.algebra

You need `fp.algebra` to write one function that works over several kinds of
values, such as an `Optional`, a `Result` and a `List`, by naming the instance
at the call. For a single known type, the type's own methods, such as
`Result.map`, are enough.

<!-- api: algebra -->

## Use one set of operations over four carriers

<!-- example: docs/examples/algebra_core.mojo -->

`map[I](twice, ...)` doubles `3` to `6` as a bare value, inside an `Optional`
and inside a `Result`, and doubles `[1, 2, 3]` to `2 4 6`; each result keeps its
native type. `flat_map[OptionalFamily](positive, Optional(-1))` lets `positive`
return an absent value. `traverse[ListFamily, OptionalFamily](positive, ...)`
returns a present list of three values for `[1, 2, 3]`, and an absent value
for `[1, -2, 3]`, stopping at `-2`.
