# fp.data

`fp.data` provides `NonEmptyList` and three sum types: `Result` for success or failure,
`Ior` for values with optional diagnostics, and `ControlFlow` for continuing or stopping a fold. Use `attempt` and `raise_on_err`
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

## Success with warnings

`Ior[E, A]` holds `Left(E)`, `Right(A)` or `Both(E, A)`. Left has diagnostics
without a value; Right has a value without diagnostics; Both keeps both. The
constructors stay distinct even when E and A are the same type. Use `isa`,
constructor indexing, consuming `unwrap` or exhaustive `fp.match`, just as for
other Choice values. Each constructor also has consuming `into_payload`: Left
and Right return their field; Both returns a native Tuple of diagnostics and
value. These extractions move the fields and accept move-only values.

Select a family explicitly for algebra and `piped` operations:

| Family | Left input | Both input | Collection behavior |
|---|---|---|---|
| `IorFamily[S]` | Skips a dependent step or lazy right operand | Runs the next step and retains earlier diagnostics | Stops after the first Left |
| `IorValidationFamily[S]` | Evaluates independent right operands | Retains a value only if every operand has one | Visits all inputs, accumulating diagnostics |

`map` transforms only the value. `pure` creates Right. `flat_map` belongs to
IorFamily and keeps diagnostics from successive steps in encounter order.
Both families use S only when combining two present diagnostics; no empty
identity is required. `NonEmptyListSemigroup` ensures that each diagnostic
collection contains at least one entry.

<!-- example: docs/examples/ior_validation.mojo -->

The accepted zero retains its warning after mapping. Independent validation
collects the warning and both errors. Sequential validation keeps the warning
and the first error, then stops before checking -3. Native raised errors stop
either policy immediately; they never become Left or Both.

These families support collection traversal **into** Ior. They do not yet
implement Ior as a Traversable source or the ApplicativeError recovery interface.
Result-specific `par_*` inference remains unchanged; select IorValidationFamily
explicitly through the generic algebra operations.
