# 3. Results and recovery

`Result[T, E]` is a sum type with two constructors: `Ok[T]` for success and
`Err[E]` for failure. Use it to return, store or collect an outcome that the
caller will handle later. `map` transforms a successful value; `flat_map`
sequences computations that can themselves return an `Err`.

Stored failures and raised errors are separate. If a callback raises, its
error propagates to the caller. Use `Capture[E]` to catch it in a `Result`.

## Transform only the active branch

<!-- example: docs/examples/results.mojo -->

`positive(21)` returns `Ok(21)`, and `map(twice)` turns it into `Ok(42)`.
`positive(-1)` returns `Err`, so `twice` never runs. `fold` borrows whichever
payload is present and calls `success` or `failure`, which gives `"ok: 42"` and
`"domain: expected a positive value"`.

`positive` returns `Ok(value)` or `Err(...)` directly; both convert to the
declared `Checked` result. `map` consumes its `Result`. For a named local, write
`value^.map(callback)`; the temporary that `positive(...)` returns is consumed
directly. A callback that changes the type produces `Result[U, E]`, and an
`Err` passes through unchanged.

These transformations can be chained. Each calls its callback only for the
case it handles:

- `flat_map` is monadic bind: it passes a successful value to a callback that
  returns another `Result`, keeping the stored error type.
- `map_err` changes the error payload.
- `or_else` recovers from an error with another `Result`.

Code that is generic over algebra instances reaches the same methods through
`map[ResultFamily[E]]`.

## Compose validation and recovery

Use `ensure` to validate a successful value, `flat_tap` to sequence a Result
computation while retaining that value, and `tap_err` to inspect a failure.
`recover` turns a stored error into a success without an extra callback that
wraps `Ok`:

<!-- example: docs/examples/result_combinators.mojo -->

For `4`, the predicate succeeds and `double` produces `8`. `record` prints the
value and returns `Ok(9)`; `flat_tap` retains `8`. For `-2`, `invalid` constructs
the error, both success callbacks are skipped, and `log_error` prints the error
before `fallback` recovers it as `0`.

All these methods consume the Result and execute immediately. The borrowing
callbacks in `ensure`, `flat_tap`, `flat_pair_with` and `tap_err` leave the
payload available for the operation to move; move-only payloads work without
copies. `recover` passes ownership of the error to its callback and returns
`Result[T, E]`, retaining both declared types. Native callback errors propagate
unchanged instead of being recovered as stored errors.

When the next step needs no input, use `followed_by(make_next)` to keep its
result or `before(make_next)` to keep the preceding success. Pass the factory
itself: it is invoked only on `Ok`. `flat_pair_with(project)` instead keeps
both the original and projected successes in a tuple. A failure returned by
any of these callbacks becomes the resulting `Err`.

The same methods are available on `piped(result^)`, together with `map_err`
and `or_else`; `.get()` extracts the already computed Result. Generic native
forwarders name raising callback errors with `X=` (`Y=` for the second
callback). A generic Piped recovery may also need `A=E, R=T` to identify the
callback's input and output types on Mojo 1.1.

## Recover selected errors

Use `recover_if(predicate, recover)` when only some stored errors have a
fallback value. Use `or_else_if(predicate, recover)` when recovery can itself
return an error. Both predicates borrow the error; a matching recovery receives
ownership of it. A non-matching error passes through unchanged, and `Ok` skips
both callbacks.

<!-- example: docs/examples/selective_recovery.mojo -->

The `retry` error becomes `42`, the `missing` error becomes `0`, and `fatal`
remains an error. Each observer runs before its predicate. After recovery
succeeds, subsequent error callbacks are skipped.

`flat_tap_err` sequences an observer returning `Result[U, E]`. An observer's
`Ok` discards `U` and retains the original error; an observer's `Err` replaces
the original error. This lets recording failures participate in the chain.
All three methods preserve the success and stored error types. In particular,
`or_else_if` cannot change `E`, because an unmatched error still needs that type.
Raised errors propagate as native errors, including errors from predicates.

Generic Piped forwarders may need `T=T, Failure=E` to identify the source
Result and `X=`/`Y=` for native errors. When a generic continuation returns a
Result, Mojo 1.1 can also require an explicit assertion that its native
signature's nominal types match the source; follow the
[generic forwarding conventions](../architecture/native-boundaries.md#generic-code).
Concrete chains such as the example infer these types.

## Compose either outcome

Use `map_both(on_ok, on_err)` to translate both payload types in one step.
`redeem(on_ok, on_err)` instead turns either payload into a success value;
both handlers return the same type, which is wrapped in `Ok`. To continue with
a computation that returns a Result, use `redeem_with(on_ok, on_err)`. Its
handlers return the same Result type and may change both the success and
stored error types.

The argument order matches `fold_owned`: success first, error second. Each
method consumes the source and runs only the handler for its original branch.
An `Err` returned by a success handler stays an error; it does not invoke the
other handler. Native raised errors also propagate unchanged.

<!-- example: docs/examples/result_outcomes.mojo -->

The first input keeps its invoice. The missing invoice receives a default,
while the fatal error becomes a readable failure message. `redeem` makes all
three final messages successful Results. Use `fold_owned` when the next step
needs the unwrapped value instead.

`attempt_tap(audit)` borrows the whole Result once, regardless of its branch.
An observer's `Ok` discards the observer's payload and retains the original
outcome; an observer's `Err` replaces it. The observer must keep the stored
error type, including its origins, because an original error may survive.
Move-only payloads and consuming library observers need no copies.

Generic `redeem_with` forwarders can pass `U=U, V=V` for the returned Result,
alongside `X=`/`Y=` for native errors and Piped's `T=T, Failure=E` for the source.
The native signatures keep Result types structural so their component types
remain available through precompiled packages. The existing
[native closure boundaries](../architecture/native-boundaries.md#known-compiler-defects)
still apply: pass borrowed views in arguments or library callable fields when
a native closure cannot carry their origins through its captures.

## Keep raised errors raised

`may_raise` is declared `raises String` and raises for `21`. Calling
`positive(21).map(may_raise)` propagates that error to the `except` block, which
prints `raised: callback failed`. The shared `String` error type does not turn
the raised error into a stored `Err`.

To convert it on purpose, call `Capture[String].args(21).run(may_raise)`. It returns
`Err("callback failed")` with the declared `String` error type.
`raise_on_err` consumes that `Result` and raises the error again. These two
operations let you choose where failures move between values and exceptions.

## Bind arguments before the callback

For a zero-argument callback use `Capture().run(callback)` or
`Capture[Failure]().run(callback)`. Construction fixes the context before the
callback is matched. `Capture.args().run(callback)` is the equivalent empty
argument bundle. Direct `run` and `stateful` calls require a context instance.
For consistent syntax across all forms, save `var capture = Capture[E]()` and
reuse `capture.run(...)`, `capture.mutable(...)`, `capture.args(...)` and the
other factories. The context stays reusable after a failure.

`Capture[E]` selects the native error type before callback inference. `args`
binds zero, one or two consumed operands; `borrow`, `mutable` and `take` bind
individual operands with their native ownership. Finish with `run(callback)`.
The callback is borrowed and called once. Pure and explicitly `raises Never`
callbacks return `Result[R, Never]`, even in a context selecting another error.

The example binds `7` and `factor=3` with
`Capture.args(7).kwargs(factor=3).run(scale)`. Expanding a typed dictionary
through `kwargs(**options^)` also works. A mutable/owned call uses
`Capture[String].mutable(balance).take(amount).run(debit)`. Its mutations stay
visible even when the callback raises.

<!-- example: docs/examples/capture_native.mojo -->

A pending bundle owns consumed arguments and keyword values and retains the
origins of borrowed arguments. Moving it transfers that responsibility; an
unused bundle destroys its owned values without calling anything. A bundle
runs once. Conflicting borrows and use after consumption are compile errors.

There may be up to two positional operands followed by one homogeneous native
keyword pack. An empty pack needs `kwargs[K=Int]()` or a typed dictionary,
because there is no value from which to infer K. Fixed named parameters,
omitted defaults and larger positional packs use a zero-argument closure or
an existing `OnceThunk`. Returning a Result nests it inside Ok; capture does
not flatten stored errors.

`Capture().stateful(step, state^)` owns explicit state for repeated calls through
a plain `def(mut State, var Input)` function. `run(value^)` captures each call;
`state()` borrows the state and `into_state()` consumes the owner. Pure and
explicitly `raises Never` steps retain `Never`, including when the context
selects another error type.
This representation preserves mutable owned state without requiring a user
callable struct or mutation through a native closure's owned captures.

Stored native function pointers work with the same argument bundles and
stateful owners. Register and memory argument/result types retain their native
calling conventions; callers need no callback-type bindings. A stateful owner
stores its pointer by value, so reassigning the original pointer does not change
the saved operation. Generic wrappers with symbolic native signatures remain
supported.

For a stored pointer with a homogeneous keyword pack, name that pack `kwargs`
in its explicit type, for example `def(var **kwargs: Int) thin -> Int`.
The callback declaration itself may use another name. Mojo 1.2 includes the pack
name in a stored pointer's type and cannot convert between names, even without
this library. Direct function declarations and captured callbacks retain their
existing keyword spelling.

The older `attempt`, `attempt_kwargs`, convention selectors and borrowed
adapters remain available. Their compiler inference limitations are described
in the [compatibility reference](../reference/data.md#select-a-native-argument-convention).
New code can use `Capture` without callback-type hints.

## Aggregate a sequence

`collect_results` consumes `Result` values in order. When the source runs out,
it returns `Ok(List[T])`. At the first `Err` it returns that error straight
away, without pulling another input, and native cleanup releases the successful
prefix and the owned source. The [configuration processor](application.md) uses
this to separate parsing from validation.

## Generic transaction helpers

`submit` and `transaction` are generic functions whose results keep the
callback's exact success and error types. The caller holds the `Result` after
both helpers return and decides how to handle it.

<!-- example: docs/examples/attempt_generic.mojo -->

The balance starts at 10. The first debit consumes a payment of `6` plus `fee=1`,
leaves the balance at 3, and returns the receipt `"3"`. The second charges
a payment of `5`, leaves the balance at -2, and returns `Declined(-2)`. Catching the
error does not roll back the debit. The same callback serves both calls, each
transaction invokes it once, and the keyword values pass through both helpers.
The inner helper binds `Capture[X].mutable(state).take(payment^)`, then
forwards the dictionary through `kwargs(**options^)` before admitting the callback.
The second call demonstrates an empty keyword pack.

## Generic transformations

`mapped` and `forwarded` consume a `Result` and borrow the same reusable
callback. Each raising helper forwards `X` explicitly. The caller then chooses
whether to sequence a successful value, translate a stored error, or recover.

<!-- example: docs/examples/result_transform_generic.mojo -->

The three inputs produce `accepted`, `notice 107` and `raised 90`:

- `Ok(6)` becomes `12` through `process`, and `accepted` returns
  `Ok("accepted")`.
- `Err(Domain(7))` skips `process` and `accepted`. `map_err(explain)` turns it
  into a `Notice` with code 107, and `or_else(recover)` recovers it.
- `Ok(-1)` makes `process` raise `ProcessingFailure(90)`. The error leaves the
  chain at once and reaches `except`; `map_err` and `or_else` do not see it.

The counter ends at two, because only the two `Ok` inputs call `process`. The
branch types that `flat_map` and `or_else` leave unchanged are part of their
native callback signatures.

Next, select among structured values with [data types and matching](matching.md).
For every operation, its ownership mode and exact error signature, see
[fp.data](../reference/data.md).
