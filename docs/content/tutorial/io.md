# 12. Programs with IO

An `IO[T, E]` from `fp.effects.async_runtime` is a value that describes a
program: when it runs, it produces a `T` or fails with domain errors of the
exact type `E`. Building one runs nothing. You compose the steps first, then
hand the whole description to `run`, which executes it and returns its
`Outcome`.

Reader and State from [chapter 9](effects.md) are deferred in the same way:
their callbacks wait until `run`. `IO`'s family is `Async[E]`, so the algebra
operations from [chapter 8](algebra.md) and `pipeline` accept it. `fp.effects`
also has a synchronous `IO[E]`, built from the Reader, Result and Optional
families and run with `run_io`. Both share `Outcome`, `EffectFailure` and
`fold_outcome`. The asynchronous `IO` can also sleep without blocking a
thread and run several fibers at once.

This chapter stays on one fiber. Import the types from
`fp.effects.async_runtime`, and `Outcome`, `EffectFailure` and `fold_outcome`
from `fp.effects`.

## Describe a program before running it

Three constructors introduce work:

| Constructor | What it holds | What runs, and when |
|---|---|---|
| `IO[T, E].pure(value)` | A value that is already evaluated | Nothing: the value exists before the call |
| `IO[T, E].delay(f)` | A function returning `T` | Once, when the run reaches this step |
| `IO[T, E].defer(factory)` | A function returning an `IO[T, E]` | Once, when the run reaches this step; then the IO it built runs |

`map(f)` transforms the success value, and `flat_map(f)` is monadic bind: its
callback returns the next `IO`, and the run continues with it. The example
prices an order and adds shipping:

<!-- example: docs/examples/io_program_first.mojo -->

`order()` is an ordinary function, so calling it runs its body: it prints
`build order` and returns an IO. The IO's steps still wait. `built` comes
before `read quantity`, because nothing in the IO has run yet. `defer(order)`
also waits to call `order`, so the line after `deferred` belongs to the first
`run`.

When `run(built^)` reaches the steps, `delay` calls `read_quantity`, which
returns 3. `map(subtotal)` turns 3 into 36, and `flat_map(add_shipping)`
builds `IO.pure(41)`. The run continues with that IO and succeeds with 41.
The second `run` reaches the deferred factory first, so it prints
`build order` and then runs the same steps.

`pipeline(io)` selects `Async[String]` from the IO, and `.get()` returns the
composed IO. The methods do the same thing directly:
`IO[Int, String].delay(read_quantity).map(subtotal).flat_map(add_shipping)`.
Each step consumes the IO before it, and `run` consumes the whole program. An
IO runs once. To repeat work, build a fresh IO, as the example does with two
values.

An IO stores its callbacks until it runs, so they must own their state. Plain
functions and library callables that own their state are accepted. Capturing
closures and borrowed callback views are rejected at compile time. A callback
for a native `map` or `flat_map` takes its argument as `var`. An `Int` callback
can also be written with a plain argument, as `subtotal` is here.

## Run a program and read its outcome

`run(program^)` consumes the IO, runs it on the calling thread and returns
once the program and all its cleanup have finished. While the program waits,
for example in a sleep, the thread parks and uses no CPU. A program that
starts no fiber, like the ones in this chapter, starts no thread.
[Chapter 14](running.md) and the guide's [run programs on a runtime](../guides/async-runtime.md#run-programs-on-a-runtime)
cover runtimes and their profiles.

The result is an `Outcome[T, E]`, an alias for
`Optional[Result[T, EffectFailure[E]]]`. It has three cases:

| Case | Outcome value | `fold_outcome` calls |
|---|---|---|
| Success | Present `Ok(value)` | `on_success(value)` |
| Failure | Present `Err(failure)` | `on_failure(failure)` with the complete `EffectFailure[E]` |
| Cancellation | Absent | `on_cancel()` |

An `EffectFailure[E]` holds `errors`, a `NonEmptyList[E]` in the order the
errors occurred, and `canceled`, which records whether cancellation also
happened during the failed run. A failure can carry both flags. Cleanup that
fails after a cancellation produces a failure with `canceled` set, not a
cancellation. The [cleanup example](#run-cleanup-whatever-the-outcome) below
produces each case.

`fold_outcome(outcome^, on_success, on_failure, on_cancel)` consumes the
outcome and calls exactly one handler. The three handlers return the same
type, and the handlers it doesn't call are destroyed without running. In the
first example, `total` returns the value, so `fold_outcome` returns 41, and
`failed` and `canceled` never run.

## Fail with a domain error and recover

`IO[T, E].raise_error(error)` builds an IO that fails with an `EffectFailure`
holding that one error, with `canceled` set to `False`. Every later `map` and
`flat_map` callback in the chain is skipped. A native callback declared
`raises E` fails the same way: its error becomes the failure and doesn't
propagate out of `run`. Its error type must be exactly `E`, or the callback
must not raise. This differs from [chapter 3](results.md), where an error
raised by a `Result` callback propagates as an exception.

Use `handle_error_with(handler)` to recover by building a replacement IO from
the failure:

<!-- example: docs/examples/async_error_recovery.mojo -->

`raise_error(41)` fails with the single error 41. `recover` takes ownership of
the complete failure, reads `errors.first()` and returns `IO.pure(42)`, so the
run succeeds with 42 and `failure` is never called. The handler runs at most
once and only for a failure. A successful program skips it. If the handler
raises, its error replaces the original failure. To keep failing on purpose,
return `IO[T, E].raise_error(...)` from the handler.

Use `attempt()` when the next step should see the failure as a value. It turns
`IO[T, E]` into `IO[Result[T, EffectFailure[E]], E]`, which succeeds with
`Ok(value)` or `Err(failure)`:

```text
var checked = IO[Int, String].raise_error("out of stock").attempt()
# running checked succeeds with Err(EffectFailure(["out of stock"], canceled=False))
```

Neither operation recovers a cancellation, or a failure whose `canceled` flag
is set. These outcomes reach `run` unchanged, and `fold_outcome` still sees
them.

## Pause with IO.sleep

`IO[NoneType, E].sleep(duration)` waits for at least `duration`, measured
from when the run reaches it, and then succeeds with `None`. The wait
suspends the fiber instead of blocking its thread. A cancellation request ends
it at once, unless the sleep is masked, as it is inside cleanup.
`io.delay_by(duration)` sleeps and then runs `io`. `io.and_wait(duration)`
runs `io`, sleeps and keeps its value, and a failure skips the sleep.

```text
var pause = Duration.milliseconds(20)    # raises Error for a negative count
var nap = IO[NoneType, String].sleep(pause)
var later = IO[Int, String].delay(read_quantity).delay_by(pause)
```

`Duration.nanoseconds`, `milliseconds` and `seconds` check their count and
raise `Error` with the message `duration outside supported range` when it is
negative or exceeds 10**18 nanoseconds. Build durations where you can handle
that error, as in a `main` that raises. A non-raising callback can't build
one. The [async runtime guide](../guides/async-runtime.md) describes the
clock, `timed` and the timeouts.

## Run cleanup whatever the outcome

`io.guarantee(finalizer)` runs the finalizer IO after `io`, whether it
succeeds, fails or is canceled. `io.on_cancel(finalizer)` runs its finalizer
only when the body observed cancellation, and otherwise drops it unopened.
Both take an `IO[NoneType, E]` and keep the body's outcome. The example runs
the same cleanup around five bodies:

<!-- example: docs/examples/io_program_cleanup.mojo -->

`protected` builds new finalizers on each call, because each IO runs once.
`guarantee` is attached first, so it is the inner finalizer. Finalizers run
innermost first, after the body.

- `write_lines` succeeds with 3. `close report` runs, the `on_cancel`
  finalizer is dropped, and `fold_outcome` calls `describe`.
- `reject` fails with `disk full`. `close report` still runs, and the outcome
  is that failure, with `canceled: False`.
- `IO.canceled()` requests cancellation of the running program. The next step
  observes it, so `stop_after` never runs, and `not reached` is never printed.
  Both finalizers run, `close report` and then `note cancellation`, and the
  outcome is a cancellation.
- When the body and its cleanup both fail, the failure keeps both errors,
  body first: `[disk full] [close failed]`.
- When cleanup fails after a cancellation, the outcome is a failure with
  `canceled: True`. `fold_outcome` calls `describe_failure`, not
  `describe_cancel`, and neither `attempt` nor `handle_error_with` would
  recover it.

Cleanup runs masked: a cancellation can't stop a finalizer partway. An IO
that is dropped without running runs neither its body nor its finalizers.
When cleanup depends on how the body ended, `guarantee_case` builds the
finalizer from the borrowed `ExitCase[E]`. It takes a library callable rather
than a plain function; the [async runtime guide](../guides/async-runtime.md)
covers it with `IO.uncancelable` and its `Poll`.

## Acquire and release resources

A `Resource[T, E]` pairs an acquisition with its release.
`Resource.make(acquire, release)` takes the acquiring `IO[T, E]` and a
function that borrows the acquired value and returns its release
`IO[NoneType, E]`. `flat_map` acquires a resource that depends on the one
before it. `use(body)` lends the resource to a function that builds the IO to
run with it. Building a Resource acquires nothing. `use` returns an IO, and
the acquisition happens when that IO runs.

<!-- example: docs/examples/async_resources.mojo -->

The outer resource acquires 20. `next_resource` borrows it and acquires 21,
and `use` lends 21 to its body, which builds `IO.pure(42)`. After the body
finishes, the releases run in reverse acquisition order: 21 first, then 20.
`release` prints when it is called, and `use` calls it at release time to
build the release IO.

The same order holds when the body fails or is canceled. With a body that
returns `raise_error(21)`, both releases run in that order and the outcome is
the failure. With a body that cancels, both run and the outcome is a
cancellation. Acquisition and release run masked, so a cancellation can't
interrupt them partway. A failed acquisition runs no release, and release
errors follow the body's errors, as cleanup errors do.

Bodies and release functions borrow the resource only while they build their
IO. The IO they return can't keep the loan. For work that suspends while it
holds a move-only resource, `use_scoped` lends it again on every poll.
`make_case` takes a release that sees the exact exit.

Next, run several fibers at once in [Concurrency with fibers](fibers.md).
