# fp.algebra

`fp.algebra` provides Functor, Applicative, Monad, Traversable and Monoid
interfaces. Their instances let you write generic operations over native values
such as `Optional`, `Result` and `List`; select the instance at each call. When
working with a single known type, you can also use its methods directly, such
as `Result.map`.

The [algebra tutorial](../tutorial/algebra.md) explains when to use `map`,
`map2`, `ap`, `flat_map`, `traverse` and `sequence` through optional order values.

<!-- api: algebra -->

## Use one set of operations over four carriers

<!-- example: docs/examples/algebra_core.mojo -->

`map[I](twice, ...)` doubles `3` to `6` as a bare value, inside an `Optional`
and inside a `Result`, and doubles `[1, 2, 3]` to `2 4 6`; each result keeps its
native type. `flat_map[OptionalFamily](positive, Optional(-1))` lets `positive`
return an absent value. `traverse[ListFamily, OptionalFamily](positive, ...)`
returns a present list of three values for `[1, 2, 3]`, and an absent value
for `[1, -2, 3]`, stopping at `-2`.
