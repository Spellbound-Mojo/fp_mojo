# fp.effects

You need `fp.effects` when a computation reads an environment, threads a state
or accumulates a log, and you want to build it from small steps with the
operations of [fp.algebra](algebra.md). The program below shows how the order of
two layers changes the result.

<!-- api: effects -->

## Choose whether a failure keeps its state

<!-- example: docs/examples/state_result.mojo -->

Both stacks start from state `10`, set it to `15` with `put`, then fail with
`Err("rejected")`. With `ResultT[State[Int], String]`, `run` returns the
failed `Result` together with the state `15`. With
`StateT[ResultFamily[String], Int]`, `run` returns only the `Err`, and the state
is lost with it.
