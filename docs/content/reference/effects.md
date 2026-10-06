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
