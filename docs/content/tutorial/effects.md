# 9. Reader, State and Writer

Some computations need configuration, an evolving state or accumulated output
as well as their main result. Reader, State and Writer describe these needs as
values that you can compose with the algebra operations from
[chapter 8](algebra.md).

| Effect | What passes between steps | How to get the result |
|---|---|---|
| `Reader[R]` | A shared environment of type `R` | `run` borrows the environment and returns the payload |
| `State[S]` | A state of type `S`, updated by each step | `run` consumes the initial state and returns `(payload, final_state)` |
| `Writer[W]` | Output combined by the monoid `W` | `run_writer` returns `(log, payload)` |

Reader and State are deferred: constructing a computation does not execute its
steps. Writer over the default `IdentityFamily` combines its values eagerly;
`run_writer` unwraps the result. Writer over a deferred base follows that base's
evaluation rules.

## Read configuration with Reader

A Reader computation uses the same environment throughout a run. This example
prices three items from a configuration containing a unit price and shipping
charge.

<!-- example: docs/examples/effects_reader.mojo -->

`PricingReader` is an alias for `Reader[TutorialPricing]`. `ask` produces a
computation that copies the environment into its payload, and `map` transforms
that payload with `quote`. Because `ask` copies, the configuration implements
`Copyable`. Reader's `run` itself only borrows the environment.

Building `standard` leaves `calls` at zero. Running it with a unit price of 12
and shipping of 5 calls `quote` once and returns `12 * 3 + 5 = 41`.

`local` runs a computation with a temporary environment. `free_shipping` keeps
the unit price and changes shipping to zero, so the promotional quote is 36.
The original configuration still has shipping of 5. The temporary environment
exists only for that run; `local` rejects a base whose result would keep it.

### Keep borrowed callbacks alive until the run

`map[PricingReader](quote, ...)` borrows the native closure. The computation
must run while `quote` is alive and unmoved. Its captured `calls` variable must
also remain alive and stable. In the example, both runs finish in the scope
that owns the closure and counter.

To store a native callback by value, adapt it with `as_unary`; use
`as_unary(f^)` when transferring a callback with owned captures. The computation
then owns that callable value. Any references the callable captures still keep
their own origin restrictions. Owning the callable does not extend the life of
the values it borrows. These are caller obligations; the pinned compiler does
not reject every invalid owner reassignment.

The same rules apply to native callbacks passed to `flat_map` and `traverse`
over deferred Reader or State instances. See
[ownership and errors](../start/ownership.md) for the shared conventions.

## Pass an evolving counter through State

State separates the value a step returns from the state passed to the next
step. Reading a counter to format a ticket need not change that counter;
allocating the next number does.

<!-- example: docs/examples/effects_state.mojo -->

`get` reads a copy of the current state. Mapping `ticket` over it returns the
payload `"ticket 10"` and leaves the state at 10. `run` therefore returns
`("ticket 10", 10)`.

`modify(increment)` changes the state and returns `None`. `flat_map` then calls
`read_counter`, whose `get` sees the updated value. Starting from 10, the
computation returns `(11, 11)`. The helper's return annotation,
`type_of(get[CounterState]())`, names the concrete deferred computation it
returns, rather than the `Int` that a later run will produce.

`put(0)` replaces the state. Sequencing another `get` after it returns `(0, 0)`.
Each call to `run` in this example starts a separate computation from state 10;
there is no global counter. To continue from a previous run, pass its final
state as the next run's initial state.

State's `run` consumes both the computation and the initial state. An `Int`
can be copied implicitly; move a state with owned resources using `^`.

## Accumulate output with Writer

Writer pairs a payload with output that can be combined. `StringMonoid` uses
the empty string as its identity and concatenation as its combination, so logs
are appended in execution order.

<!-- example: docs/examples/effects_writer.mojo -->

`tell("ready")` records a log with a `None` payload. It does not print anything;
the example unwraps the value with `run_writer` and prints the log itself.

`writer` constructs a Writer value from `(log, payload)`. The initial value has
log `"start; "` and payload 3. `flat_map(add_fee, ...)` passes 3 to `add_fee`,
which returns payload 5 and log `"fee +2"`. Writer combines the logs into
`"start; fee +2"`.

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
