# 9. Reader, State and Writer

Some computations need configuration, an evolving state or accumulated output
as well as their main result. Reader, State and Writer describe these needs as
values that you can compose with the algebra operations from
[chapter 8](algebra.md).

| Effect | What passes between steps | How to get the result |
|---|---|---|
| `Reader[R]` | A shared environment of type `R` | Pipeline `.run(environment)` borrows the environment and returns the payload |
| `State[S]` | A state of type `S`, updated by each step | Pipeline `.run(state)` consumes the initial state and returns `(payload, final_state)` |
| `Writer[W]` | Output combined by the monoid `W` | Pipeline `.run()` returns the base carrier of `(log, payload)` |

Reader and State are deferred: constructing a computation does not execute its
steps. Writer over the default `IdentityFamily` combines its values eagerly;
`.run()` unwraps the result. Writer over a deferred base follows that base's
evaluation rules; unwrapping does not execute that base.

## Read configuration with Reader

A Reader computation uses the same environment throughout a run. This example
prices three items from a configuration containing a unit price and shipping
charge.

<!-- example: docs/examples/effects_reader.mojo -->

`PricingReader` is an alias for `Reader[TutorialPricing]`.
`asks[PricingReader](quote)` projects a price directly from the borrowed
configuration. The configuration only needs `Movable`; neither the projection
nor Reader's `run` copies it. Use `ask` when the payload should be a copy of
the whole environment.

Building `standard` leaves `calls` at zero. Running it with a unit price of 12
and shipping of 5 calls `quote` once and returns `12 * 3 + 5 = 41`.

`local` runs a computation with a temporary environment. `free_shipping` keeps
the unit price and changes shipping to zero, so the promotional quote is 36.
The original configuration still has shipping of 5. The temporary environment
exists only for that run; `local` rejects a base whose result would keep it.

### Keep captured references alive until the run

`asks` owns its callback value, including the callback's concrete captures.
Here `quote` captures a reference to `calls`, so both runs finish while that
counter is alive and stable. Owning a callback does not extend the life of
anything it borrows. Transfer a callback with owned captures using `^`.

Native closures passed to `.map`, `flat_map` and `traverse` over deferred
Reader or State instances are borrowed until execution; plain functions are
copied. Keep a closure alive and unmoved, or store it by value with `as_unary`; `as_unary(f^)` transfers
owned captures. Captured references retain their origin restrictions in either
case. These are caller obligations; the pinned compiler does not reject every
invalid owner reassignment.

See [ownership and errors](../start/ownership.md) for the shared conventions.

## Pass an evolving counter through State

State separates the value a step returns from the state passed to the next
step. Reading a counter to format a ticket need not change that counter;
allocating the next number does.

<!-- example: docs/examples/effects_state.mojo -->

`inspect[CounterState](ticket)` borrows the current state to format a ticket.
It returns the payload `"ticket 10"` and moves the unchanged state onward, so
`run` returns `("ticket 10", 10)`. This projection also works for move-only
state. Use `get` when the payload should be a copy of the whole state.

`modify(increment)` changes the state and returns `None`.
`.product_r(get[CounterState]())` combines that transition with a state read
and keeps the read's payload. Both recipes exist before combination, but their
execution remains deferred until `.run(10)`, which returns `(11, 11)`.
Use `.followed_by(factory)` when constructing the next recipe must also wait.

`put(0)` replaces the state. Sequencing another `get` after it returns `(0, 0)`.
Each call to `run` in this example starts a separate computation from state 10;
there is no global counter. To continue from a previous run, pass its final
state as the next run's initial state.

State's `run` consumes both the computation and the initial state. An `Int`
can be copied implicitly; move a state with owned resources using `^`.

When only one output matters, finish with `.run_value(initial_state)` for the
payload or `.run_state(initial_state)` for the final state. These keep the
base effect and consume the unused output without copying it. See
[State execution outputs](../reference/effects.md#choose-a-state-execution-output)
for a complete example, including Optional state computations.

## Accumulate output with Writer

Writer pairs a payload with output that can be combined. `StringMonoid` uses
the empty string as its identity and concatenation as its combination, so logs
are appended in execution order.

<!-- example: docs/examples/effects_writer.mojo -->

`tell("ready")` records a log with a `None` payload. It does not print anything;
the example selects the log with `.run_log()` and prints it. Use `.run_value()`
when only the payload is needed, or `.run()` for both outputs. These keep the
base effect and move the selected output without copying the other one.

`writer` constructs a Writer value from `(log, payload)`. The initial value has
log `"start; "` and payload 3. `.map(add_fee)` changes the payload to 5,
and `.tell("fee +2")` appends output, producing log `"start; fee +2"`.
The callback is an ordinary `Int`-to-`Int` function. Use `flat_map` when the
next computation itself produces both a payload and a log.

`listen` keeps that log and pairs the payload with a copy of it. `censor` then
formats the outer log with brackets. The final result is:

```text
("[start; fee +2]", (5, "start; fee +2"))
```

The log copied by `listen` records the text before `censor` changed the outer
log. Copying requires a `Copyable` log type. `ListMonoid[T]` is another built-in
choice when the output should be a list of records rather than text.

## Combine effects with monad transformers

A monad transformer adds an effect to a base Monad. `StateT[M, S]` adds state
to `M`; `ResultT[M, E]` adds a stored error. `State[S]` is shorthand for
`StateT[IdentityFamily, S]`, with analogous definitions for Reader and Writer.
Use `lift` to embed an existing base computation in a transformer layer.

The order of layers determines the shape of the result and what survives a
failure:

<!-- example: docs/examples/state_result.mojo -->

Both computations set the state to 15 and then fail with `Err("rejected")`.
`product_r` sequences the two recipes and retains the failure's result. StateT
recipes infer their family; `pipeline[Keep]` explicitly selects the erased
ResultT layer before combining it with another computation of that layer.
`ResultT[State[Int], String]` returns `(Err("rejected"), 15)`, so the caller can
inspect the state reached before failure. Its outer Result is a value inside
State's computation; run it with `run[State[Int]]`.

`StateT[ResultFamily[String], Int]` returns only `Err("rejected")`. A successful
result would hold `(payload, state)` inside `Ok`, but an error has neither. Run
this computation with its StateT instance. Neither ordering rolls back external
mutations performed by callbacks.

## Handle errors when a computation runs

A stored `Err` belongs to the Result layer. A native error raised by a callback
still propagates as an exception with its original type. For Reader and State,
that happens when `run` executes the callback, not when `map` or `flat_map`
constructs the computation.

On Mojo 1.1, catch a raising deferred computation inside `try`/`except`; a plain
`raises` on the enclosing function cannot propagate its error alias. The
[troubleshooting guide](../guides/troubleshooting.md#symptoms) describes the
diagnostic. Reusing a computation also requires an explicit copy when its type
supports one; a consumed computation cannot be run again.

For other transformer combinations and their result shapes, see
[fp.effects](../reference/effects.md). The
[algebra reference](../reference/algebra.md) describes the shared operations,
and the [architecture chapter](../architecture/algebra.md) explains how
deferred computations preserve their types, ownership and origins.
