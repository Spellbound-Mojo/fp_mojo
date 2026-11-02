# 14. Running and testing async programs

The programs in [chapter 12](io.md) and [chapter 13](fibers.md) ran through
the free `run`, which blocks the calling thread until the program and its
cleanup finish. This chapter covers where a program runs: on a runtime you
keep, on a pool of threads for blocking calls, or on another execution
context for part of its length. It also covers how a host cancels a running
program and how a test runs one on virtual time and in chosen scheduling
orders.

The examples import their names from `fp.effects.async_runtime`, and
`CancellationToken`, `Interruption`, `Outcome` and `fold_outcome` from
`fp.effects`. The runtime runs on Linux x86-64 and macOS arm64.

## Keep a runtime for many programs

`run(program)` creates what the program needs, runs it, and releases it
again. A long-running application instead creates one `Runtime` from an
`IORuntimeConfig` and runs many programs on it, as Cats Effect's `IORuntime`
does. A runtime is an explicit value: there is no global runtime.

<!-- example: docs/examples/async_runtime.mojo -->

`Runtime(config)` starts the two workers that `Profile.work_stealing(2)`
asks for, and raises `OSError` if a thread cannot start. Each
`runtime.run(program(n))` consumes its program, runs it on those workers,
parks the calling thread until it completes, and returns its `Outcome`.
`program(n)` starts a fiber that squares `n` on whichever worker takes it,
joins it, and adds `n`, so the three runs print `2`, `6` and `12`. After the
last run, `runtime.fibers()` lists no live fibers.

The configuration's profile decides where fibers run:

| Profile | Where fibers run | What it promises |
|---|---|---|
| `Profile.work_stealing(n)` | In parallel on `n` worker threads that steal each other's queued work | A fiber's own steps run in order, one at a time, even when it moves between workers. The order of fibers that are ready together varies between runs |
| `Profile.current_thread()` | On the thread that runs the root, one at a time | The same, plus a deterministic FIFO order: one input gives one schedule |

`IORuntimeConfig()` selects the work-stealing profile with one worker per
logical processor, and the current-thread profile on a host with a single
logical processor. `Profile.work_stealing()` counts the processors when it is
called; a count outside 1 to 32768 raises `Error`. The example names two
workers because the profile's printed form includes the count. Outcomes,
laws, ownership and error order are the same on both profiles. The
differences you can observe are the ones the table names, and a race whose
sides finish together: the current-thread profile reports the left side, and
the work-stealing profile reports the first completion it observes.

Choose the current-thread profile for code that shares unsynchronized state
between fibers, or that needs the deterministic order. On the work-stealing
profile fibers share mutable state only through `Ref`, `Deferred`, `Queue`,
`Semaphore` and other synchronized owners, as the
[thread-safety contract](../guides/async-runtime.md#share-state-across-threads)
describes. One setting selects the profile, for the free `run` as for a
`Runtime`:

```text
var config = IORuntimeConfig()
config.profile = Profile.current_thread()
var outcome = run(program^, config)
```

The free `run(program, config)` also follows the profile. On the
work-stealing profile it runs the program on the calling thread as the first
worker and starts the others only when there is work to steal. A
`runtime.run` costs more per call, because the program goes to another
thread and back, so run many short steps inside one program rather than
many short programs. Any number of threads may call `run` on one runtime at
once. Calling it from inside a program that runs on that runtime aborts with
a message, because it would block a worker the program may need; use `start`
and `join` there.

There is no `close()`. Copies of a `Runtime` share it, and each `run` holds a
copy until it returns. When the last copy is dropped, here at the end of
`main`, the runtime cancels any fibers still running, waits for them, and
joins its worker threads. `Driver` and `TestControl`, below, ignore the
profile and always use the current thread.

## Call blocking code without stalling other fibers

A native callback given to `IO.delay` or `map` runs on the thread that runs
its fiber, and it must return promptly. A call that waits on the operating
system belongs in `IO.blocking` or `IO.interruptible`, which run it on
another thread while the fiber suspends:

<!-- example: docs/examples/async_blocking.mojo -->

`IO[Int, Int].blocking(slow_read)` runs `slow_read` once when the program
reaches it and resumes the fiber with `42`. Other fibers of the root keep
running meanwhile. As in Cats Effect, the call cannot be canceled: a
cancellation or a timeout waits for the function to return.

`IO.interruptible(wait_for_a_minute)` lends the function an `Interruption`
handle for the length of the call. The 20 ms `timeout_to` requests
cancellation; `interruption.sleep` returns `False` as soon as the request
arrives, the function returns `0`, and the runtime discards that late result
and completes the fiber canceled. The fallback `IO.pure(-1)` wins, so the
second line prints `-1`. `requested()` reports the request, and the handle's
`await_readable` and `await_writable` wake on it as `sleep` does. No signal
is sent: a function blocked in a system call that does not go through the
handle is not woken.

Both take a plain `def() thin` function, or `def(Interruption) thin` for
`interruptible`, or a library callable such as a `OnceThunk`, with error `E`
or none. Closures are rejected. The function, its result and its error move
to another thread and may be destroyed there, so they must be safe to
transfer, as every value stored in an `IO` must be.

Without configuration, each root creates a private `BlockingPool` on its
first blocking call. On the work-stealing profile a call instead runs on the
thread that made it, after that worker hands its queue of fibers to a
replacement thread, up to `IORuntimeConfig.max_blocking_threads` calls at
once (64 by default). A pool you configure is always used, on either
profile. `BlockingPool(1, Duration.seconds(5))` has one worker that retires
after five idle seconds, so the two calls under `both` run one after the
other, and their sum is `84`. A nonpositive maximum raises. Copies of a pool
share its workers, so you can pass one pool to several roots. When the last
copy is dropped, the pool waits for its queued and running calls, then joins
its workers.

## Run part of a program somewhere else

`io.eval_on(target)` runs `io` on another execution context and then resumes
the caller where it was, as Cats Effect's `evalOn` does. The target is an
`ExecutionContext`, which converts implicitly from a `Runtime` or a
`BlockingPool`. Use it for coarse work: a CPU-bound computation on a
dedicated runtime, or a subsystem that blocks on its own pool.

<!-- example: docs/examples/running_contexts.mojo -->

`IO.execution_context()` produces the context running the current program,
as an `Optional[ExecutionContext]`. `where` turns it into text:

- Under the free `run` there is no `Runtime` value, so it is `none`. The same
  holds under `Driver` and `TestControl`.
- Inside `compute.run`, it is that runtime, which writes as
  `runtime(work_stealing(2))`.
- Inside `where().eval_on(compute)` it is the target, the same runtime, even
  though the caller runs under the free `run`.
- `where().eval_on(files).flat_map(ThenHere())` reads `blocking_pool` inside
  the region. `ThenHere` runs after the region, back in the caller, where the
  context is `none` again.
- Under `compute.run`, the same program prints `blocking_pool, then
  runtime(work_stealing(2))`: nested regions return to each caller's
  context.

The region runs as its own root on the target, and the caller waits for it as
for a callback registration; a fiber never moves between schedulers. On a
work-stealing runtime the region is one of the runtime's programs, on its
workers. On a current-thread runtime or a `BlockingPool` it holds one thread
of that pool for its whole length, and its fibers run on that thread in
the current-thread order.

`start_on(target)` is `eval_on(target).start()`: an ordinary child of the
caller whose work runs on the target. Here it sums 1 to 1000 on `compute`
while the caller sums 1 to 100. `JoinAndAdd` joins the child with
`join_with`, whose fallback runs only if the child was canceled, and adds the
two parts: `500500 + 5050 = 505550`.

`background_on(target)` is `eval_on(target).background()`. `io.background()`
returns a `Resource[Background[T, E], E]`: its use starts `io` as a fiber
beside the body, and its release cancels the fiber and waits for it, cleanup
included. The body borrows a `Background` handle. `join()` builds an IO that
waits for the fiber and takes its outcome, and `cancel()` cancels it and
waits. The outcome is taken once; a second join that runs aborts. Here the
fiber reads its context on `files`, and `join_where` joins it, so the last
line prints `blocking_pool`. A failure that no join took is reported when
the resource is released, as for a dropped `Fiber` handle.

The rules a region follows:

- **Outcomes.** Success, failure and cancellation pass through unchanged. If
  `io` cancels itself, the caller is canceled too.
- **Cancellation.** Canceling the caller during the region cancels `io` and
  waits for it, so its finalizers run on the target exactly once. Under
  `uncancelable` the region runs to its end.
- **Children.** Fibers that `io` starts belong to the region and are
  canceled and drained when it ends, not when the caller's fiber ends. This
  is the one difference from Cats Effect, where `evalOn` keeps the same
  fiber.
- **Ownership.** `io`, its value and its error move to the target's threads
  and back. A `Fiber`, `Supervisor` or `Poll` in the value or error type is
  rejected at compile time, because each is tied to the root that made it.
  The check does not see such values captured inside `io`'s callables;
  using one there is unsupported.
- **Lifetime.** The region holds a copy of its target until it finishes, so
  the target cannot shut down while the region runs.

Each region costs about as much as a `runtime.run`, against nanoseconds for a
bind, so keep regions coarse.

## Wait for a file descriptor

Library authors build pipes, sockets and process I/O on two low-level waits
in `fp.effects.async_runtime.protocols`. `await_readable[E](fd)` and
`await_writable[E](fd)` return an `IO[NoneType, E]` that suspends the fiber
until the descriptor is ready:

<!-- example: docs/examples/async_descriptors.mojo -->

The reader parks in the poller; it does not poll on a timer. The writer
sleeps 5 ms and writes the byte `42`, the descriptor becomes readable,
and `ReadByte` reads it without blocking, so the program prints `read: 42`.
Hang-up and error conditions also count as ready, and the next read reports
them. Readiness is reported once per IO, so wait again before each retry.

You own the descriptor: keep it open and nonblocking until the IO completes,
then close it, as `main` does at the end. Cancellation completes the wait
canceled and removes its registration. The wait never fails with `E`; a
negative descriptor, or a wait outside `run`, a `Driver` or `TestControl`,
aborts.

## Cancel a program from the host and wait for its cleanup

A host cancels a program through a `CancellationToken`. Pass one to
`run(program, token)` or `runtime.run(program, token)`, and any thread that
holds a copy can call `token.cancel()`. The request does not itself wait:
`run` returns only after the program, its fibers and its finalizers have
finished, with the program's outcome.

A host that runs its own loop owns the program through a `Driver` instead.
It polls the program, requests cancellation, and keeps polling until the
cleanup has run:

<!-- example: docs/examples/async_host_cancel.mojo -->

`Driver(program^, CancellationToken(), clock)` consumes the program; it runs
nothing until polled. The first `poll()` runs the program up to its 30-second
sleep, on a manual clock that never moves by itself. `request_cancel()`
requests cancellation without waiting. The following polls cancel the sleep
and run the `guarantee` finalizer, which prints `released`, and the loop ends
when `poll()` reports `Progress.completed`. `finish()` then consumes the
driver and returns the outcome. It is canceled, so `fold_outcome` selects
`canceled` and the program prints `canceled: True`.

A `Driver` is a linear owner: it has no destructor that abandons the work, so
you poll it to completion and call `finish`. A masked region or a finalizer
that is still running delays completion; cancellation never cuts cleanup
short. While nothing is runnable, `driver.park(timeout)` waits for the next
deadline, a wake from another thread, a ready descriptor or the timeout,
without spinning:

```text
var progress = driver.poll()
while not progress.completed:
    if not progress.runnable:
        driver.park(host_timeout)
    progress = driver.poll()
```

## Test timeouts on virtual time

A test of a timeout should not wait for the timeout. `TestControl` runs a
program on a manual clock that starts at zero and moves only when the test
advances it, as Cats Effect's `TestControl` does:

<!-- example: docs/examples/async_test_control.mojo -->

`slow` sleeps 60 seconds and then produces `42`; `timeout_to` gives it five
seconds before the fallback `7` wins. `TestControl(program^)` consumes the
program. `tick()` runs everything runnable without moving time, which leaves
the program waiting for the sleep's deadline and the timeout's.
`next_interval()` reports the time to the earliest one, five seconds, so the
program prints `5000`. `tick_all()`
alternates ticking and advancing to the next deadline until the program
completes. At five virtual seconds the timeout cancels `slow` and the result
is `7`. The test finishes at once; no real time passes.

The other operations step the same clock: `tick_one` takes one root poll,
`advance` and `advance_and_tick` move time by a duration, `tick_for` runs
through every deadline within one, and `is_deadlocked` reports an incomplete
program with nothing runnable, no deadline and no callback registration
waiting. Like a `Driver`, the control is a linear owner: `results()` takes
the outcome once the program completes, and a program that cannot complete
needs `request_cancel()` and further ticks first.

`TestControl` always uses the current-thread profile, whatever the
configuration says. An `eval_on` region it reaches runs on its target in
real time, and its end arrives as a wake from another thread, observed at a
later tick.

## Explore and replay scheduling orders

The runtime leaves some orders unspecified: which of several ready fibers
runs first, and so which waiter a `Queue`, `Semaphore` or `Ref` serves first.
By default `TestControl` runs fibers that are ready together in FIFO order,
so a test that passes once passes every time, possibly only because of that
order.

Constructed with a seed, `TestControl(program, seed=s)` explores instead:
whenever several fibers are ready together, the seed chooses which runs
first. Run a check of promised behavior over a range of seeds to cover the
orders the contract allows:

```text
for seed in range(1000):
    var control = TestControl(program(), seed=UInt64(seed))
    control.tick_all()
    var trace = control.trace().value().copy()
    if not promised(control^.results()):
        abort(String("failed; replay with ", trace))
```

Each run builds a fresh program, because a program runs once. Take
`trace()` before `results()`, which consumes the control. The trace is a
`ScheduleTrace`: its `seed()` and its `choices()`, one index for each phase
that had more than one candidate. It prints as `seed=7 choices=2/3,0/2`,
each choice over its candidate count. `ScheduleTrace.parse` reads that text
back, and `TestControl(program(), replay=trace)` repeats the run exactly. A
seed alone also replays its run. A program that no longer offers the
recorded candidates aborts, naming the first choice that diverged. A control
built without a seed returns `None` from `trace()`.

Exploration keeps the orders the runtime promises: a fiber's own steps,
FIFO `Queue` values, every `Deferred` reader receiving the value, and the
left side of a race whose sides finish together. It does not vary virtual
time, events the test delivers itself, or the work-stealing pool, whose
order comes from real threads; stress tests cover the pool. A replayed trace
that includes an `eval_on` region is exact only up to the region's end.

## Where to go next

This is the last tutorial chapter. The
[async runtime guide](../guides/async-runtime.md) covers the rest of the
runtime as tasks and decisions: generic programs over the capability
dictionaries, the provider matrix against Cats Effect, the full comparison of
the two profiles, and the measured responsiveness of each. The architecture
pages explain how the runtime meets its contracts:
[explicit async state machines](../architecture/async-state-machines.md),
[async fibers](../architecture/async-fibers.md),
[wake-driven execution](../architecture/async-scheduler.md), including the
work-stealing pool, blocking hand-off and execution contexts, and
[payload thread safety](../architecture/async-thread-safety.md). For every
operation's exact signature, ownership and errors, see the
[fp.effects.async_runtime reference](../reference/effects.async_runtime.md)
and its [protocols](../reference/effects.async_runtime.protocols.md).
