# 3. Results and recovery

`Result[T, E]` is a sum type with two constructors: `Ok[T]` for success and
`Err[E]` for failure. Use it to return, store or collect an outcome that the
caller will handle later. `map` transforms a successful value; `flat_map`
sequences computations that can themselves return an `Err`.

Stored failures and raised errors are separate. If a callback raises, its
error propagates to the caller. Use `Capture[E]` to catch it in a `Result`.

## Construct a Result with one type argument

Use `ok[ErrorType](value)` to infer the success type from the value, or
`err[ValueType](error)` to infer the error type. Each creates a complete Result
and consumes its payload. This follows [Cats' `asRight` and `asLeft`](https://github.com/typelevel/cats/blob/main/core/src/main/scala/cats/syntax/either.scala#L473):
you only name the side that has no value to infer from.

<!-- example: docs/examples/result_constructors.mojo -->

Both factories infer `Result[Int, String]` in the example, and those values
enter `pipeline` directly. Literals, move-only values and borrowed origins
retain their native types. Supply the missing side's type explicitly; the
factories do not choose an arbitrary default.

When a function already declares `-> Result[T, E]`, returning `Ok(value)` or
`Err(error)` remains the concise form. Those uppercase constructors describe
one case; the lowercase factories return the complete Result immediately.

## Turn optional input into a Result

Use `pipeline(optional^).to_result(make_error)` when absence should become a
stored error. A present payload becomes `Ok`; an empty Optional invokes the
zero-argument factory and stores its returned error in `Err`. Both payload and
error types are inferred, so the next Result operations need no type annotation:

<!-- example: docs/examples/optional_result.mojo -->

This follows [Cats OptionT's `toRight`](https://github.com/typelevel/cats/blob/main/core/src/main/scala/cats/data/OptionT.scala#L495),
named `to_result` for this library's Result type. Pass the factory itself so
error construction stays lazy. `.to_optional()` converts back, discarding any
stored error; `.swap()` can exchange the cases afterward.

Both the source and a library factory are consumed, including cleanup of a
skipped factory. Native captured factories are borrowed and remain reusable.
Move-only payloads, error values and borrowed origins are retained. A factory's
raised native error propagates unchanged; it does not become an `Err`. Select
native callback errors with `.raising[MyError]()` before conversion, as with
other pipeline operations. The selected native error remains available for
subsequent callbacks.

## Finish with a value

Use `get_or(value)` for an already available default, `get_or_else(make_default)`
to compute one lazily, or `value_or(on_err)` when the fallback depends on the
error. All return a plain success value. Callbacks run only on `Err`;
`get_or(value)` evaluates its argument normally before the call.
Use `to_optional()` when you want to discard error information and keep only
the success in Mojo's native `Optional`.

<!-- example: docs/examples/result_values.mojo -->

The same methods finish a `pipeline` directly: no `.get()` or private payload
access is needed. Each consumes its Result, so use `result^` for a named
local. Move-only payloads work without copying. A skipped library callback is
destroyed; a captured native callback remains borrowed and can be reused.

When both branches need formatting, finish with `.fold(describe, describe_error)`.
Each handler borrows its payload, and the pipeline releases that payload after
the handler returns. The example formats either branch as a String without
copying the stored error or adding `var` to the handler. Use `fold_owned`
instead when a handler needs to consume or return its input. Both pipeline
terminals consume their Result; direct `result.fold(...)` is available when
you want to keep the original Result.

These operations follow [Cats Either's `valueOr`, `getOrElse` and `toOption`](https://github.com/typelevel/cats/blob/main/core/src/main/scala/cats/syntax/either.scala).
Mojo uses snake_case and an explicit zero-argument factory for a lazy default.
For constants, `get_or(0)` avoids a factory. It consumes the supplied default
even on success; an unused default is destroyed. See the
[eager and lazy default example](pipelines.md#choose-a-constant-or-lazy-default).
The callback must return exactly `T`, including its origins; the library does
not widen the success type. Unlike `recover`, `value_or` returns `T` rather
than `Result[T, E]`. Use `raise_on_err()` to return `T` or raise the stored error.
It also finishes a pipeline directly: `pipeline(result^).raise_on_err()`.
This follows [Cats EitherT's `rethrowT`](https://github.com/typelevel/cats/blob/main/core/src/main/scala/cats/data/EitherT.scala#L251),
using Mojo's native exception mechanism. The stored `E` is preserved, independent
of the pipeline's selected callback error. A stored Never keeps extraction pure.

A native error raised by a fallback propagates unchanged. Plain functions infer
their error; non-raising closures and closures raising `Error` or `Never` work
directly. For a closure with a custom error, select it before the callback:
`pipeline(result^).raising[MyError]().get_or_else(factory)`, or the corresponding
`value_or(handler)`. This is the existing pipeline error context, independent
of the stored `E`. Library callables keep their declared error automatically.
Selecting a closure's error first also lets incompatible callbacks receive
normal diagnostics on Mojo 1.2.

## Work with the error as a value

`swap()` exchanges the two Result cases: `Ok(value)` becomes `Err(value)` and
`Err(error)` becomes `Ok(error)`. The type changes from `Result[T, E]` to
`Result[E, T]`. This follows [Cats EitherT's `swap`](https://github.com/typelevel/cats/blob/main/core/src/main/scala/cats/data/EitherT.scala#L104)
and its underlying Either operation.

Use `.swap().to_optional()` to extract only the error, as the example above
does, or `.swap().map(transform).swap()` to work through the success API on
the error side. For a simple error transformation, `map_err` remains shorter.
Swapping twice restores the original case and type. Payloads move without
copies, including move-only errors and values that retain borrowed origins.

`pipeline(result^).swap()` selects the exchanged Result family, so subsequent
`map` and `flat_map` operate on the former error channel. Its native error
selection stays unchanged: a stored error is never raised by `swap`.

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

The example starts with `pipeline(ok[String](value))`: the value supplies its
success type, and `String` supplies the stored error type. The pipeline keeps
that context through validation and recovery. `raise_on_err()` finishes with
the successful `Int`, raising any stored error that remains. Use `.get()` only
when the caller needs the complete Result for later handling.

Pass native callbacks directly. For a captured callback that raises a custom
native error, select `.raising[MyError]()` before that callback; this is
independent of the stored `String` error. The direct Result methods remain
available when a pipeline is unnecessary.

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
For a reusable threshold, matching rule or observer, bind its leading arguments
with `partial`. The same named partial works in selected pipelines and direct
Result methods; see [reusable Result handlers](../reference/data.md#reuse-result-predicates-and-observers).
No wrapper lambda is needed to forward the remaining borrowed argument.

Raised errors propagate as native errors, including errors from predicates.

The pipeline starts with `err[Int](message)`, selecting the missing success
type once. After recovery, `.fold_owned(success, failure)` renders either
branch as a plain String. It consumes the Result, moves its active payload
into the corresponding handler, and returns that handler's value. Both
handlers return the same type, but only one runs. No intermediate `.get()` or
manual case extraction is needed, and the callbacks need no family or payload
type annotations. The order matches Result's `fold_owned`: success first,
error second.

Native handlers are borrowed, and named shared Kleisli chains remain reusable.
Other library handlers are consumed, including cleanup of the skipped handler;
each uses its declared shared, mutable or consuming receiver mode. Returned
values and raised errors retain their exact types and origins. Select a custom
native closure error with `.raising[E]()` before folding, as with other
callbacks. A library handler retains its own declared error.

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

These native handlers are passed directly, and their return types determine
the next Result types. `raise_on_err()` finishes the example with its String.
Use `kleisli` when you need to build and reuse a composed callback; it is not
required to pass a single function. See [function composition](../reference/functions.md)
for reusable chains and the [native boundary reference](../architecture/native-boundaries.md)
for generic forwarding and compiler-specific restrictions.

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
Save `var capture = Capture[E]()` when reusing direct `run` or `stateful`
calls. The context stays reusable after a failure. When only binding
arguments, use the type-level factories shown below, such as
`Capture[E].args(...)`; no saved context is needed.

`Capture[E]` selects the native error type before callback inference. `args`
binds zero to eight consumed operands; `borrow`, `mutable` and `take` bind
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

For an ordinary consuming function, bind all arguments in one `args(...)` call.
Their types and positions are inferred, including move-only values. An all-owned
bundle can also grow with `.take(value^)` up to eight operands. No wrapper
closure is needed for these calls:

<!-- example: docs/examples/capture_arguments.mojo -->

The invoice receives four arguments and returns either its receipt or the exact
String it raises. `value_or(explain)` renders either outcome as a plain String.
Argument binding does not invoke the callback; `run` does.

The purchase binds three different conventions: exclusive access to the
balance, shared access to the price, and ownership of the item name. Keyword
fees follow those operands. A raised error is captured without rolling back
changes the callback already made to the balance.

Mixed borrow/mutable conventions support up to three positional operands. A
homogeneous native keyword pack can follow at most three positional operands. An empty pack needs `kwargs[K=Int]()` or a typed dictionary,
because there is no value from which to infer K. Fixed named parameters,
omitted defaults and calls beyond these limits use a zero-argument closure or
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
