# fp.data

You need `fp.data` when a function returns its failure to the caller instead
of raising it, or when a `fold_until` step decides to stop. The
[results tutorial](../tutorial/results.md) introduces `Result` and `attempt`
with a runnable program.

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
