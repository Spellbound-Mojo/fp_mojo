# fp.effects

Reader, State and Writer describe computations that read an environment, pass
state between steps or accumulate a log. Compose them with the operations of
[fp.algebra](algebra.md), and combine effects with monad transformers such as
`ResultT` and `StateT`. The example below shows how transformer order determines
whether a failed computation returns its final state.

Start with the [effects tutorial](../tutorial/effects.md) for standalone Reader,
State and Writer programs, deferred evaluation and callback ownership.

<!-- api: effects -->

## Choose whether a failure keeps its state

<!-- example: docs/examples/state_result.mojo -->

Both stacks start from state `10`, set it to `15` with `put`, then fail with
`Err("rejected")`. With `ResultT[State[Int], String]`, `run` returns the
failed `Result` together with the state `15`. With
`StateT[ResultFamily[String], Int]`, `run` returns only the `Err`, and the state
is lost with it.

## Recover stored errors through a transformer

ReaderT, WriterT, OptionalT and StateT support `ApplicativeError` when their
base Monad does. StateT also requires copyable state for this capability.
Use `.recover[Family](handler)` for a replacement value or
`.or_else[Family](handler)` for a replacement effect. Native raised errors
propagate unchanged.

StateT handlers restart from the input at the recovery boundary; ResultT above
State keeps the updated state. Reader handlers share the environment, WriterT
handlers supply their own log when the base fails, and OptionalT leaves absence
unchanged. See the [recovery reference](combinators.md#recover-a-selected-error-layer)
for the runnable comparison and ownership rules.
