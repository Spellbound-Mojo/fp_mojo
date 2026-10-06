# fp.data

`fp.data` provides two sum types: `Result` for success or failure, and
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
