# 7. A configuration processor

The two programs in this chapter combine lazy iteration, Result composition and
pattern matching. The first parses and validates configuration, stopping when a
line or setting is invalid. The second routes a queue of commands with guarded
clauses and handles a typed dispatch error. Both express their parsing,
validation and dispatch rules as plain functions.

## Parse and validate configuration

The configuration processor follows five steps:

1. Parse each `key=value` line into `Result[Entry, ConfigError]`.
2. Stop at the first parse error with `collect_results`.
3. Validate the complete entry list with `parsed^.flat_map(validate)`.
4. Format only a valid `Config` with `checked^.map(describe)`.
5. Fold the final `Ok` or `Err` into one message with a match.

<!-- example: docs/examples/config_parser.mojo -->

For `["batch=12", "workers=4"]`, both lines parse, `validate` records each entry
with `fold_until`, and `complete` accepts the result, so `configure` returns
`"ready: batch=12, workers=4"` after reading two lines.

Each scenario in `main` stops at a different step:

| Input | Result | Lines parsed |
|---|---|---|
| `["bad", "workers=4"]` | `error: syntax` | 1 |
| `["batch=12", "workers=no", "ignored=99"]` | `error: integer` | 2 |
| `["batch=12", "batch=4"]` | `error: unknown or duplicate key` | 2 |
| `["batch=12", "workers=0"]` | `error: positive values required` | 2 |
| `["batch=2", "workers=4"]` | `error: workers exceeds batch` | 2 |
| `[]` | `error: missing key` | 0 |

`collect_results` stops at the first parse error, so the lazy `map` never reads
`"ignored=99"`. Validation runs only after every line has parsed: `record`
returns `Break` at the first invalid entry, and the match on `ControlFlow` turns
it into `Err`. `parse` converts the native error from `Int(...)` into
`ConfigError("integer")` at its own boundary.

## Route commands with guarded clauses

The job router dispatches a submitted or retried job when its guard allows it,
and defers every other command. Guards and dispatches append to a trace that
reaches every clause through the match's context, and one dispatch raises a
typed error.

<!-- example: docs/examples/job_router.mojo -->

The queue holds four commands, and the program prints
`dispatched 1; deferred; deferred; dispatch failed for job 3`:

1. `Submit(Job(1, 4))` passes the guard, because its cost is at most 5, and is
   dispatched.
2. `Retry(Job(2, 6))` fails the guard, so the catch-all clause defers it.
3. `Cancel(Job(4, 1))` has no guarded clause and is deferred.
4. `Submit(Job(3, 5))` passes the guard, and `dispatch` raises
   `DispatchFailure(3)`.

A lazy `map` callback cannot raise, so `routed` calls `route` through `attempt`,
which keeps the failure as an `Err` that `outcome` formats. The trace records
the order of the calls:
`check 1, dispatch 1, check 2, defer, defer, check 3, dispatch 3`.

To look up any operation used here, start from the
[API reference](../reference/index.md). The [example gallery](../examples/index.md)
lists every program on the site.

Next, use the same operations across `Optional`, `Result` and `List` in
[functors, applicatives and monads](algebra.md), then compose computations with
[Reader, State and Writer](effects.md).
