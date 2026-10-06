# 8. Functors, applicatives and monads

The `Result` methods from [chapter 3](results.md) are examples of operations
that also make sense for other types. Mapping changes the value inside an
`Optional`, each element of a `List`, or the successful value of a `Result`.
`fp.algebra` gives these operations shared interfaces, so you can use the same
operation with different contexts.

This chapter starts with the native instances, then uses optional order values
to explain mapping, applicative combination and monadic bind. The final example
collects optional results with `traverse` and `sequence`.

## Choose an instance

An *instance* supplies the operations for a particular family of values. Select
it in square brackets: `map[OptionalFamily](f, value)` maps an `Optional`, while
`map[ListFamily](f, values^)` maps a list. The values keep their native types;
selecting an instance does not wrap them in another container.

| Instance | A value in that family | What `map` transforms |
|---|---|---|
| `IdentityFamily` | `Int`, `String` or another bare value | The value itself |
| `OptionalFamily` | `Optional[T]` | A present value; absence skips the callback |
| `ResultFamily[E]` | `Result[T, E]` | An `Ok` payload; `Err` passes through |
| `ListFamily` | `List[T]` | Every element, in order |

The type holding the payload is often called the *carrier*. For example,
`Optional[Int]` is a carrier of `OptionalFamily`. The family is chosen at
compile time, and the call infers its payload and result types.

<!-- example: docs/examples/algebra_core.mojo -->

`twice` turns `3` into `6` in each context. For the list, it transforms all three
elements into `2`, `4` and `6`. `pure[ResultFamily[Error]](3)` introduces `3`
as an `Ok`; `pure[OptionalFamily](3)` would make a present `Optional`, and
`pure[ListFamily](3)` a one-element list. Here, `pure` names an operation that
introduces a value into a context. It does not assert that other callbacks are
free of side effects.

When a function already works specifically with `Result`, its methods remain
convenient: `value^.map(f)` uses the same implementation as
`map[ResultFamily[E]](f, value^)`. Use the family interface when the context is
a parameter of your code or when combining it with other algebra operations.

## Choose the operation by what the next step needs

| Interface | Operation | Use it when |
|---|---|---|
| Functor | `map` | A callback transforms a payload into an ordinary value |
| Applicative | `pure`, `map2`, `ap` | You introduce a value or combine computations whose inputs are already specified |
| Monad | `flat_map` | The next computation depends on the previous payload and returns a value in the same family |
| Traversable | `traverse`, `sequence` | You collect effectful results while preserving the source's shape |
| Monoid | `empty`, `combine` | Values have an associative combination and an identity, such as concatenation and an empty string |

Each Monad is also an Applicative and a Functor. Choose the operation that
describes the dependency between your steps: a price calculation may only need
`map`, while a stock check can return an absent value and needs `flat_map`.

<!-- example: docs/examples/algebra_choices.mojo -->

### Transform a payload with map

`pure[OptionalFamily](3)` represents a quantity of three. Partially applying
`subtotal` to a unit price of 12 gives a function that prices that quantity.
`map` calls it and returns a present total of 36.

Mapping preserves the outer context. `in_stock(8)` returns an empty
`Optional`, so `map[OptionalFamily](in_stock, Optional(8))` produces a present
`Optional` containing that empty `Optional`. Its type is
`Optional[Optional[Int]]`.

### Sequence a dependent computation with flat_map

`flat_map` is monadic bind. It passes the payload to a callback and uses the
callback's result as the next value in the same family. With `in_stock` and
quantity 8, the result is an empty `Optional[Int]`, without another layer.
An absent input skips `in_stock` entirely.

For `ResultFamily[E]`, the same operation passes an `Ok` payload to the next
computation and stops on `Err`. Stored errors keep their type `E`; a native
error raised by a callback still propagates as an exception.

### Combine independent inputs with map2 and ap

The price and quantity can be available independently. `map2` combines their
payloads only when both optionals are present: 12 times 3 gives 36. An absent
quantity gives an absent total.

`map2` takes a library `Binary` callable. `partial(subtotal)` binds no arguments
and adapts the two-argument function to that protocol. This is why the example
passes a partial rather than the native function directly.

`ap` uses a function that is itself inside a context. Here,
`Optional(partial(subtotal, 12))` holds the pricing function, and applying it to
`Optional(3)` also gives a present 36. An absent function or argument produces
an absent result. The wrapped function must be a library `Unary` callable;
`partial(subtotal, 12)` supplies one.

Independent inputs do not imply parallel execution. Arguments to `map2` are
computed before the call. If producing the right input should be skipped when
the left has failed, use [`map2_lazy`](../reference/algebra.md#map2_lazy), whose
right operand is a `Thunk` called at most once.

The instance determines how combination works. With `ListFamily`, `map2`
forms every pair, in left-major order. Prices `[10, 20]` and quantities
`[1, 2]` produce `[10, 20, 20, 40]`; they are not zipped together.

## Collect results with traverse and sequence

`traverse[ListFamily, OptionalFamily]` transforms a list of inputs into one
optional list of outputs. The first family names the source shape; the second
names the context returned by the callback.

<!-- example: docs/examples/algebra_traversal.mojo -->

For `[1, 3, 5]`, every quantity is available, so `traverse` returns a present
list with those three values. For `[1, 8, 3]`, `available(8)` returns absence.
Traversal stops after two calls, and the last quantity is never checked.
An empty source succeeds with a present empty list and makes no callback calls.

Use `sequence` when the optional results already exist. It turns
`List[Optional[Int]]` into `Optional[List[Int]]`: `[Optional(1), Optional(3)]`
becomes a present `[1, 3]`, while any absent element makes the result absent.
It cannot undo work performed while constructing those results. Use `traverse`
when you want a failure to prevent later callback calls.

The same pattern with `ResultFamily[E]` returns the first stored error. These
operations stop at failure; they do not accumulate validation errors.

## Ownership and callback effects

Algebra operations consume their carriers. Move a list or named `Result` with
`^`, or copy it explicitly if you need to keep it. Implicitly copyable values,
such as the `Optional[Int]` quantities above, can be passed directly.

`map`, `flat_map` and `traverse` borrow native functions and closures. In the
examples here they call them before returning. Library callable values, such
as partials, are consumed by the operation. A callback that may run more than
once must support repeated calls.

Callbacks may have side effects, as the traversal counter shows. The
[algebraic laws](../architecture/laws.md) apply under their stated purity,
termination and ownership assumptions. Reader and State add another timing
rule: their callbacks run later, when the computation is run. The
[next chapter](effects.md) explains that rule through configuration, state
and logging examples.
