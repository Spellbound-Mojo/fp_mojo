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

`get_or_else(factory)` borrows a named shared `Thunk`, so the same lazy
factory can serve several Results or Optional pipelines. A moved or temporary
factory is consumed, including disposal when skipped. Use `mut_ref(factory)`
to retain mutable state; receiver selection stays explicit in the argument.

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

## Replace or discard a success

`result^.fill(value)` returns `Result[U, E]`, inferring U from the replacement.
`result^.void()` returns `Result[NoneType, E]`. An Err passes through unchanged;
neither method raises it. Both consume the Result without copying, and `fill`
also consumes its eagerly evaluated replacement, destroying it on Err. The
output preserves the exact value and error origins, including move-only state.

These direct methods follow the same mapping path as Pipeline replacement and
discarding. `fill` is the library's spelling of Cats `Functor.as`; `void` is
replacement with None. See [replacing or discarding a successful value](../tutorial/results.md#replace-or-discard-a-successful-value)
for the executable example and eager evaluation rules.

## Attach a value to a success

`result^.tuple_left(value)` returns `Result[Tuple[U, T], E]` and
`result^.tuple_right(value)` returns `Result[Tuple[T, U], E]`. The attachment
type is inferred. Both consume the source and attachment without copying;
move-only payloads and attachments are supported. An Err stays stored and
destroys the eagerly evaluated attachment. All three types retain their
original origins.

These methods follow Cats `Functor.tupleLeft` and `tupleRight`, delegating to
the same mapping callback as Pipeline attachment. Use `product` to combine
two carriers; tuple attachment adds an ordinary value to one carrier.

## Flatten a nested Result

`nested^.flatten()` removes one layer from `Result[Result[T, E], E]`, returning
`Result[T, E]`. An outer error passes through; on outer success, the inner
Result is returned as it is. The method consumes the nested value without
copying payloads or raising stored errors. No callback or type annotation is
needed at the call.

This follows [Cats `FlatMap.flatten`](https://typelevel.org/cats/api/cats/FlatMap.html).
Both layers must use the same complete error type, including origins; use
`map_err` explicitly when they differ. Borrowed values and errors retain their
original owners. `pipeline(nested^).flatten()` remains available for a fluent
continuation. When applying a function that already returns a Result,
`flat_map(function)` avoids constructing the extra layer in the first place.

## Reuse Result predicates and observers

Bind a native predicate or observer with `partial`, then pass it by name to
several operations. Direct Result and Piped Result methods borrow that stored
callback: `.ensure`, `.tap_err`, `.flat_tap_err`, `.attempt_tap`,
`.recover_if` and `.or_else_if` use their existing branch and error rules.
A predicate or observer borrows its payload; recovery still consumes the
matching stored error. See [callback reuse](../start/ownership.md#reuse-callbacks-by-name)
for explicit moves and deferred lifetimes.

<!-- example: docs/examples/reusable_result_handlers.mojo -->

Family-parameterized Piped calls, such as `.tap_err[Family](observer)`, also
retain named partials through the selected family's execution. Skipped branches
do not invoke the callback or copy its bound arguments.

## Reuse an error context

Construct `var capture = Capture[E]()` once, then use `capture.run(callback)`,
`capture.args(...)`, `capture.borrow(...)`, `capture.mutable(...)`,
`capture.take(...)`, `capture.kwargs(...)` and `capture.stateful(step, state)`.
The context stores no arguments or callback state. Reuse it after successes
and failures; each argument bundle still runs once, while stateful owns its
repeated-call state. Pure callbacks retain Never even when E is another type.
Type-level factories such as `Capture[E].args(...)` remain available.
Prefer those type-level forms when using only argument factories: Mojo treats
these factories as static calls, so a saved context used only through them
still triggers an unused-variable warning. `run` and `stateful` use the saved
context as an actual receiver.
`args` accepts up to eight owned positional arguments; an all-owned bundle
can also append operands with `take`. Mixed conventions and keyword calls
support up to three positional operands.

The owner returned by `stateful` is also a mutable unary library callable.
Pass `mut_ref(owner)` to retain its updated state, or `owner^` to transfer it
to an operation. Each call consumes an input and returns `Result[R, E]`;
native errors are captured, so the callable itself raises `Never`. Existing
`run(value)`, `state()` and `into_state()` methods keep the same behavior.

Use `.map(mut_ref(owner))` to keep an outcome for each input, or
`.traverse(mut_ref(owner))` to stop on the first Err and collect successes.
The Result target is inferred. A failed call retains mutations already made
to the state. An empty source does not call the function. A lazy map calls it
only when pulled, and an abandoned owner releases its state without invoking
the function. Native origin tracking keeps borrowed owners alive; sequential
updates through `owner.run(...)` before a lazy pull are visible to that pull.

This is an immediate native-state adapter. For a deferred program that threads
state through composed effects, use [State](effects.md#program-against-a-selected-state).

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

## Fold a Result and choose what to keep

<!-- example: docs/examples/result_once.mojo -->

`Format` is a `OnceUnary` that owns its prefix. `value^.map(formatter^)` moves
it in and calls it once, turning `Ok(12)` into `Ok("value 12")`.
`fold_owned` consumes both temporary `Show` handlers and calls only the one for the
`Ok` branch, which prints `used once: value 12`.

Use `fold` to borrow the Result payload or `fold_owned` to move it into the
selected handler. Either method accepts shared, mutable or consuming library
handlers. Named shared handlers stay borrowed; moved or temporary handlers are
consumed, including the one for the inactive branch. A consuming receiver takes
priority for an owned handler, followed by mutable and shared invocation.

Pass `mut_ref(on_ok)` and `mut_ref(on_err)` to retain mutable state. The example
folds `Ok(12)` this way, then prints handler counts `1 0`: only the success
handler ran. Its borrowing fold leaves the source Result available afterward.
You can mix a named shared handler with a moved or retained mutable handler:
`shared` remains reusable across the two mixed library calls, which produce `12` and
`22`. Errors and outputs retain their exact types and origins.

A plain function or stored thin function pointer can occupy either position
beside a library handler. `fold_owned(double, shared)` doubles an `Ok` payload;
`fold(mut_ref(on_ok), double)` doubles an `Err` payload while keeping the
mutable success handler available. No adapter or explicit type argument is
needed for these calls. To mix a capturing native callback with a library
handler, use `BorrowSignature[Payload, Output].capture(callback)` for `fold`
or `as_unary(callback)` for `fold_owned`.

Existing `fold_once` and `fold_owned_once` calls remain supported as explicit
forms that consume both handler arguments. Ordinary calls no longer need a
different method name solely because a callback owns captures or mutable state.

## Sequence a reusable factory

`result^.before(factory)` runs an effect on success and keeps the original
success value; `result^.followed_by(factory)` keeps the factory's Result.
Both skip the factory on Err. A named shared `Thunk` stays borrowed and can be
used again. Its Result must have the same stored error type, while a raised
native error propagates separately. Move a factory with `factory^` to transfer
its captures, or pass `mut_ref(factory)` to retain mutable state.
These methods also work through selected pipelines and their family policies;
see [sequencing effects](functions.md#select-family-and-native-errors-before-callbacks).

## Capture a thunk’s outcome

<!-- example: docs/examples/attempt_once.mojo -->

`attempt_once(message^)` consumes `Message("used once")`, calls it once, and
returns `Ok("used once")`, which prints `message: used once`. An empty message
raises `7`, so `attempt_once` returns `Err(7)` with the thunk's declared `Int`
error, and the program prints `error: 7`.

Shared `Thunk` and mutable `MutableThunk` values work with the same function.
When several modes are available, consuming wins, then mutable, then shared.
A fully bound `partial(add, 2, 3)` is already a thunk and can be passed directly.
The result and error types are inferred, including `Never` for pure thunks.
`Capture[E]().run(thunk^)` uses the same rules: the thunk retains its own error
type, while `E` selects the errors of native callbacks. The example passes the
fully bound `partial` directly to `Capture[Error]().run`.

Use `attempt_once(mut_ref(counter))` to retain a named thunk's state. The
example captures the first counter call's error, then succeeds on the second
call; `counter.calls` is 2 afterward. Each invocation consumes only the reference.
Passing `counter^` instead transfers the original callback into the operation.

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
