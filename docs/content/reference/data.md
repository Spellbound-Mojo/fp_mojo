# fp.data

`fp.data` provides `NonEmptyList` and three sum types: `Result` for success or failure,
`Ior` for values with optional diagnostics, and `ControlFlow` for continuing or stopping a fold. Use `Capture[E]` and `raise_on_err`
to convert between native exceptions and stored failures. Bind operands with
`args`, `borrow`, `mutable`, `take` and `kwargs` before `run(callback)`. The
[results tutorial](../tutorial/results.md) introduces these operations with a
complete program.

<!-- api: data -->

## Construct a Result

`ok[E](value)` infers T and returns `Result[T, E]`; `err[T](error)` infers E
and returns the same complete type. Both consume the payload without copying
or raising it. The other side's type is explicit. See the
[constructor example](../tutorial/results.md#construct-a-result-with-one-type-argument).

`Ok(value)` and `Err(error)` remain the case constructors for typed returns and
pattern matching. Their existing implicit conversions are unchanged.

## Extract a Result value

`value_or(on_err)` consumes an error to compute a plain `T`.
`get_or(default_value)` uses an already evaluated default, consuming it even on success.
`get_or_else(make_default)` calls its zero-argument factory only on `Err`.
`to_optional()` moves a success into native `Optional[T]`, discarding errors.
These Cats-inspired operations are also terminal methods on `pipeline(result)`;
they return the value directly. See [finishing with a value](../tutorial/results.md#finish-with-a-value)
for lazy defaults, ownership and native error selection.

`value_or(handler)`, `recover(handler)` and `or_else(handler)` also borrow
reusable shared Kleisli handlers without copying their captures. They run only
on `Err`; a successful value skips the handler. Passing `handler^` instead
transfers ownership, including disposal when the handler is skipped.
`recover_if(predicate, handler)` and `or_else_if(predicate, handler)` reuse
these handlers for matching errors. Their predicate borrows the stored error,
and a nonmatch retains it without calling the handler.

`map_err`, `map_both`, `redeem` and `redeem_with` also borrow named shared
chains. Two-handler methods accept any mix of chains and native functions.
Exactly one handler runs for the original outcome; a returned failure or a
native raise never invokes the other handler.

`raise_on_err()` returns the success or raises the stored error with its exact
type. This also finishes a Result pipeline directly; it consumes the carrier
without copying its payload.

`swap()` exchanges Ok and Err and returns `Result[E, T]`. It also chains on
`pipeline(result^)`, retaining the native error setting. Combine it with
`to_optional()` to keep only the error; see [working with the error as a value](../tutorial/results.md#work-with-the-error-as-a-value).

## Reuse an error context

Construct `var capture = Capture[E]()` once, then use `capture.run(callback)`,
`capture.args(...)`, `capture.borrow(...)`, `capture.mutable(...)`,
`capture.take(...)`, `capture.kwargs(...)` and `capture.stateful(step, state)`.
The context stores no arguments or callback state. Reuse it after successes
and failures; each argument bundle still runs once, while stateful owns its
repeated-call state. Pure callbacks retain Never even when E is another type.
Type-level factories such as `Capture[E].args(...)` remain available.
`args` accepts up to eight owned positional arguments; an all-owned bundle
can also append operands with `take`. Mixed conventions and keyword calls
retain their two-positional-argument limit.

<!-- example: docs/examples/capture_context.mojo -->

## Select a native argument convention

This section documents the retained compatibility entry points. Prefer
`Capture` for new code; its argument-first boundary also checks incompatible
callbacks without explicit callback-type bindings. See the
[ownership and error contract](../tutorial/results.md#bind-arguments-before-the-callback).

Mojo 1.2 can fail while selecting between native read, mutable and owned
callback overloads. An optional named compile-time selector chooses the
callback's argument convention before inference:

| Callback positional arguments | Selector |
|---|---|
| None | `zero=True` |
| One read-only resource | `read=True` |
| One `var` argument, or a default scalar such as `Int` | `owned=True` |
| One `mut` argument | `mutable=True` |
| Two arguments | Combine `read`, `owned` or `mut` in order: `read_read=True`, `read_owned=True`, `read_mut=True`, `owned_read=True`, `owned_owned=True`, `owned_mut=True`, `mut_read=True`, `mut_owned=True` or `mut_mut=True` |

For `attempt_kwargs`, the selector describes only the positional prefix; the
keyword values are always owned. Selectors must be `True`. Omit the selector
when ordinary inference works; existing positional type bindings are preserved.

<!-- example: docs/examples/attempt_selectors.mojo -->

The callback remains borrowed and reusable. Selection does not copy arguments
or captures, erase result/error types, or change when mutation becomes visible.
The example retains the updated balance even when `debit` raises.

Choose the selector matching the callback. For a normal diagnostic on an
incompatible selector, also supply `F=type_of(f)`, for example
`attempt[mutable=True, F=type_of(f)](f, value)`. Without that hint, Mojo 1.2
can crash before rejecting the call. Inside a generic forwarder, the same hint
is `F=F`. An overloaded generic forwarder may need
the same convention selection at its own call boundary; a selector inside its
body cannot resolve inference at the caller. See the
[compiler details](../architecture/native-boundaries.md#compile-time-convention-selectors).

The four borrowed adapters remain supported and can be saved for repeated calls:

| Callback arguments | Call |
|---|---|
| One `mut` argument | `attempt(mutating(f), value)` |
| One `var` argument | `attempt(consuming(f), value^)` |
| `mut` then `var` | `attempt(mut_owned(f), first, second^)` |
| `mut`, `var`, then `var **kwargs: K` | `attempt_kwargs(mut_owned_kwargs(f), first, second^, key=value)` |

<!-- example: docs/examples/attempt_adapters.mojo -->

Factories borrow the callback without calling or copying it. A saved adapter
can be reused while that callback remains alive and unmoved. Arguments retain
their native conventions, and the result retains the exact success and error
types; mutations remain visible after an error. Callbacks that mutate owned
captures still require the documented `@always_inline` workaround on Mojo 1.2.

Choose the adapter matching the callback's convention. An incompatible factory
call can still crash Mojo 1.2 during inference instead of reporting a type
error. These four forms cover a subset of the conventions supported by selectors;
see the [compatibility qualification](../architecture/native-boundaries.md#convention-adapters).

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
elements may be removed. Selected `pipeline[NonEmptyListFamily](values)` chains
continue in ListFamily after filtering or compaction. The target Applicative determines short-circuiting,
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
