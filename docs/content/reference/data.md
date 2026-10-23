# fp.data

`fp.data` provides `NonEmptyList` and two sum types: `Result` for success or failure, and
`ControlFlow` for continuing or stopping a fold. Use `attempt` and `raise_on_err`
to convert between stored failures and native exceptions. The
[results tutorial](../tutorial/results.md) introduces these operations with a
complete program.

<!-- api: data -->

## Consume handlers in a transformation and a fold

<!-- example: docs/examples/result_once.mojo -->

`Format` is a `OnceUnary` that owns its prefix. `value^.map(formatter^)` moves
it in and calls it once, turning `Ok(12)` into `Ok("value 12")`.
`fold_owned_once` consumes both `Show` handlers and calls only the one for the
`Ok` branch, which prints `used once: value 12`.

## Capture the failure of a consuming thunk

<!-- example: docs/examples/attempt_once.mojo -->

`attempt_once(message^)` consumes `Message("used once")`, calls it once, and
returns `Ok("used once")`, which prints `message: used once`. An empty message
raises `7`, so `attempt_once` returns `Err(7)` with the thunk's declared `Int`
error, and the program prints `error: 7`.

## Non-empty collections and validation

`NonEmptyList(first, rest)` consumes a guaranteed first element and an optional
native List tail. `NonEmptyList[T].from_list(values^)` returns `Optional`: None
for an empty List, otherwise a non-empty value sharing the moved List buffer.
The checked constructor `NonEmptyList[T](values=values^)` instead raises
`Error` on empty input. The keyword distinguishes checking a List from storing
a List as the singleton payload. `first()`
borrows the guaranteed first element; `len` is constant time. `into_list()` and
consuming iteration transfer the existing buffer without copying elements.

Choose `NonEmptyListFamily` explicitly for `map` and `traverse`, or for fluent
methods on `piped(values^)`. Mapping and every successful traversal retain the
non-empty shape. `filter` and `filter_map` return ordinary Lists because all
elements may be removed. The target Applicative determines short-circuiting,
accumulation, branching and deferred execution.

`NonEmptyListSemigroup[E]` concatenates errors in order and admits move-only
values. Supply it explicitly to `ValidationFamily` or `par_*`; default validation
inference remains restricted to native List errors. There is no empty identity
and no NonEmptyList Monoid.

<!-- example: docs/examples/non_empty_validation.mojo -->

Both failed operands contribute an error. Traversing the three positive inputs
succeeds with a NonEmptyList whose first element is 2. Stored failures remain
Result errors; any native raised error retains its original type.
