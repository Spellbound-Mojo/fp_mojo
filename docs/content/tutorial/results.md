# 3. Results and recovery

`Result[T, E]` holds either a success value `Ok[T]` or a stored failure
`Err[E]`. Use it when a failure is data that should travel through your
program, be collected, or be decided on later. `map`, `flat_map` and the other
methods run a callback only on the branch it applies to. A callback that raises
still raises: a `Result` never turns a raised error into `Err` unless you ask
for it with `attempt`.

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

Each method runs only on the branch it applies to, and the methods chain:

- `flat_map` takes a success callback that already returns a `Result`.
- `map_err` changes the error payload.
- `or_else` recovers from an error with another `Result`.

Code that is generic over algebra instances reaches the same methods through
`map[ResultFamily[E]]`.

## Keep raised errors raised

`may_raise` is declared `raises String`, and raises for `21`. That failure
leaves `positive(21).map(may_raise)` through native exception propagation, and
the `except` block prints `raised: callback failed`. It does not become a
stored `Err`, even though `Checked` also uses `String` as its error type.

To convert it on purpose, call `attempt(may_raise, 21)`. It returns
`Err("callback failed")` with the declared `String` error type.
`raise_on_err` consumes that `Result` and raises the error again. Put the
recovery policy at this explicit boundary.

## Forward arguments through attempt

`attempt` calls its callback exactly once with the arguments you give it. The
example shows each rule with its own values:

- `attempt(scale, 7, factor=3)` forwards the positional `7` and the keyword
  `factor=3` to the captured closure `scale`, which declares
  `var **options: Int`. It returns `Result[Int, Never]` holding `21`, because
  `scale` does not raise, and the counter records one call.
- A second call consumes a `StringDict[Int]` through `**options^`, returns
  `28`, and brings the same counter to two.
- A `mut` prefix keeps the callback's changes even when it raises. `debit`
  takes `balance` from 5 to 2, then to -2 while returning `Err("overdrawn")`.

What `attempt` accepts:

- Zero, one or two positional arguments, optionally followed by a
  homogeneous native keyword pack. The bridge function and the prefixes are positional-only.
- Every positional argument, including those with defaults; omitted prefixes
  are not supported.
- Borrowed resource arguments stay usable after the call. Move a named resource
  that the callback consumes with `^`.
- Conflicting mutable borrows are rejected as in native calls.
- Ordinary fixed keyword parameters and generic positional packs are not
  supported. Bind those forms in a local native closure, when Mojo admits that
  closure's encoding.
- A callback that returns an ordinary `Result` gets it nested inside `Ok`;
  `attempt` does not capture that `Result`'s error.

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

The balance starts at 10. The first debit charges `purchase=6` and `fee=1`,
leaves the balance at 3, and returns the receipt `"3"`. The second charges
`purchase=5`, leaves the balance at -2, and returns `Declined(-2)`. Catching the
error does not roll back the debit. The same callback serves both calls, each
transaction invokes it once, and the keyword values pass through both helpers.
The helpers call the public `attempt` directly, with no callable object or
result cast.

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
