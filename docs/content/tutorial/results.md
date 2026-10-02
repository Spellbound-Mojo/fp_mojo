# 3. Results and recovery

Use `Result[T, E]` when success or domain failure is a value that should travel through your program. Native raised errors remain available independently.

<!-- example: docs/examples/results.mojo -->

## Transform only the active branch

The successful value `21` becomes `42` through `map`. The negative input produces `Err`, so `twice` is never called. `fold` borrows the active payload and produces a single String through either `success` or `failure`.

`positive` returns `Ok(value)` or `Err(...)` directly: both convert to the declared `Checked` result. `map` is a method that consumes its Result. For a named local, write `value^.map(callback)`; the temporary returned by `positive(...)` is consumed directly. A type-changing callback creates `Result[U, E]`, moving an inactive error through unchanged.

Use `flat_map` when the success callback already returns a Result. Use `map_err` to change the error payload, or `or_else` to recover from an error with another Result. The methods chain, and each invokes only the corresponding active branch. Code that is generic over algebra instances reaches the same methods through `map[ResultFamily[E]]`.

## Observe the raised callback failure

`may_raise` uses `raises String`. Its failure exits `map` through native exception propagation and reaches the `except` block. It does not become a stored error, despite `Checked` also using String as its domain error type.

To make that conversion deliberately, use `attempt(may_raise, 21)`. It returns `Err("callback failed")`, retaining the declared String error type. To reverse it, consume that Result with `raise_on_err`. Recovery policy belongs at that explicit boundary.

`attempt` accepts zero, one or two positional arguments and invokes the callback once. The example forwards positional `7` and keyword `factor=3` to a native captured `scale` callback, producing `Result[Int, Never]` because the callback is pure. The target explicitly declares `var **options: Int`. Its counter records exactly one call. A second call consumes a `StringDict[Int]` through `**options^`, returns `28` and advances the same counter to two. Mutable prefixes retain the callback's changes even when it raises. The debit example changes balance from 5 to 2, then to -2 while returning Err("overdrawn"). Conflicting mutable borrows reject as in native calls. Borrowed resource arguments remain usable; move named consumed resources with `^`. Supply all positional arguments, including defaults. Keyword forwarding supports homogeneous native packs with zero through two positional prefixes; the bridge function and prefixes are positional-only. Ordinary fixed keyword parameters, omitted prefixes, generic positional packs remain unsupported. Bind those forms in a local native closure when its native encoding is admitted. Returning an ordinary Result from the callback nests it inside `Ok`; it does not capture that Result's domain error.

## Aggregate a sequence

`collect_results` consumes Results in order. Exhaustion returns `Ok(List[T])`. The first `Err` returns immediately, with no extra input pull. Native cleanup releases the successful prefix and owned source. The [configuration processor](application.md) uses this to separate parsing from validation.

See [fp.data](../reference/data.md) for every operation, its ownership mode, and exact error signatures. Next, use [patterns and guards](matching.md) to select among structured values.

## Generic transaction helpers

`submit` and `transaction` are generic functions. Their returned values retain the
target's exact success and error types. The caller keeps the Result after both
helpers return and decides how to handle it.

<!-- example: docs/examples/attempt_generic.mojo -->

The first debit leaves balance 3 and returns a receipt. The second leaves balance
-2 and returns `Declined(-2)`. Catching the error does not roll back the debit.
The callback is reused, each submitted transaction invokes it once, and the
keyword values pass through both helpers. The generic declarations call the
existing public `attempt` directly; no callable object or result cast is needed.

## Generic transformations

`mapped` and `forwarded` consume a Result while borrowing the same reusable
callback. Each raising helper forwards X explicitly. The caller then chooses
whether to sequence a successful value, translate a stored error, or recover.

<!-- example: docs/examples/result_transform_generic.mojo -->

The three inputs produce `accepted`, `notice 107` and `raised 90`. The stored
Domain error skips `process`, then becomes a Notice and is recovered. A raised
ProcessingFailure leaves the chain immediately and reaches `except`; `map_err`
and `or_else` do not capture it. The counter is two because only the two Ok
inputs invoke `process`. The unchanged branch types of `flat_map` and `or_else`
are part of their native callback signatures.
