# Async runtime preview

`fp.effects.async_runtime` provides pure-Mojo asynchronous programs with Cats
Effect vocabulary: `IO`, `Resource`, `Deferred`, `Queue`, `Semaphore`, races,
and timeouts. This opt-in preview is qualified on the pinned Mojo 1.2.0 Linux
x86-64 checkout. It executes cooperatively on one host thread. Callbacks must
return promptly; `IO.delay` and `IO.eval_io` perform synchronous work inside
their step. The preview does not offload blocking IO or use compiler coroutines.

Import application types from `fp.effects.async_runtime`, preferably as `ar`
when the synchronous `fp.effects.IO` family is also in scope. Custom leaf and
scoped-body contracts live in `fp.effects.async_runtime.protocols`. Canonical
`Outcome`, `EffectFailure`, `ExitCase`, `CancellationToken`, and `Permit` stay
in `fp.effects`; `pipeline` and `tail_rec_m` retain their existing import paths.
See the [application reference](../reference/effects.async_runtime.md) and
[extension reference](../reference/effects.async_runtime.protocols.md).

## Sequence and iterate

An `IO[T, E]` describes work that produces `T` or fails with the exact domain
error `E`. Building one runs nothing, and a value runs once; repeating work
builds a fresh `IO`, as a function returning `IO` does. `IO.pure` owns an
evaluated value, `IO.delay` evaluates a function when reached (one with no
return value gives an `IO[NoneType, E]`), and `IO.defer`
builds the `IO` when reached, so recursive programs build lazily. `flat_map`,
`map`, and `handle_error_with` take plain functions or owned library callables.
`pipeline` selects the `Async[E]` family from an `IO`. Sequencing is
sequential; use `both` to run children concurrently.

<!-- example: docs/examples/async_sequencing.mojo -->

Long sequences run iteratively. Binds, recoveries, and finalizers become frames
on one run-loop stack, so a chain, a recursion through `defer`, or a
`tail_rec_m` loop of any length uses constant native stack. Each step of
`tail_rec_m` consumes its state and returns `ControlFlow`: `Continue` transfers
the next state and `Break` the result. `traverse` into `Async[E]` and `attempt`
work the same way. Long runs yield to the host after a fixed number of steps.

<!-- example: docs/examples/async_iteration.mojo -->

An `IO` keeps origins only through `T` and `E`, so the callbacks it stores must
own their state. `IO`'s methods, `Pipeline`, `tail_rec_m`, and every free
operation that can return an `IO` (`map`, `flat_map`, `traverse`, `if_effect`,
and `fp.iteration`'s traversals, effectful folds, and searches) copy plain
functions and accept library callables that own their state. Capturing
closures and borrowed callback views are rejected at compile time. A callable
struct holding a pointer cannot be detected and must not outlive what it
points to. Raising native callbacks keep
their exact error, which must be `E`.

## Own resources and failures

`Resource[T, E].make(acquire, release)` pairs an acquisition `IO` with a
release built from the borrowed resource. `use` acquires masked, lends the
resource to a body that builds an `IO`, runs it, then releases masked with the
exact exit. Dependent resources from `flat_map` release in reverse order. Bodies
and releases borrow the resource only while building their `IO`, which cannot
retain the loan. When work that suspends must keep using a move-only resource,
`use_scoped` polls a `ScopedMachine` body with a fresh loan on every poll.
`make_case` takes a `CleanupMachine` release that also sees the exact exit, like
Cats Effect's `Resource.makeCase`.

<!-- example: docs/examples/async_resources.mojo -->

`handle_error_with` consumes the complete noncanceled `EffectFailure[E]` and
builds a replacement. `attempt` materializes ordinary failure as a `Result`.
Cancellation-only outcomes and failures with a cancellation flag bypass both
recovery operations. Full ordered errors remain available through canonical
`fold_outcome`. `guarantee`, `guarantee_case`, and `on_cancel` run their
cleanup masked after the body, innermost first, with body errors before cleanup
errors.

<!-- example: docs/examples/async_error_recovery.mojo -->

`IO.uncancelable` builds a masked region from a `Poll[E]`; `io.restore(poll)`
runs part of it with the cancellation state outside the region. A masked
success survives a cancellation requested inside it, and the next checkpoint
observes the request. `IO.canceled` requests cancellation of the running
program, and a mask defers observing it.

## Run work beside its owner

`io.start()` is an `IO[Fiber[T, E], E]`: it starts `io` as a fiber that runs
beside the program that started it, its owner, and returns a handle.
`fiber^.join()` consumes the handle and parks until the child and its cleanup
finish, then produces its `Outcome[T, E]`. `join_with(fallback)` produces the
child's value, fails with its errors, or runs `fallback` if it was canceled;
`join_with_never()` and `join_with_unit()` wait or produce unit instead.
`fiber.cancel()` requests cancellation and waits for the child to finish; as
in Cats Effect, that wait cannot itself be canceled. `fiber.request_cancel()`
only requests.

A child shares its owner's error type `E`; a program with another error type
runs as a leaf with its own fibers. Fibers start unmasked with their own
cancellation, and an owner's cancellation does not reach them directly. Unlike
Cats Effect, fibers never outlive their owner: when the owner's program
finishes, it cancels its live children and completes only after they finish,
cleanup included. Dropping a handle neither stops nor detaches the child. A
child the owner never joined does not change the owner's outcome, and a child
canceled before it first runs runs nothing, not even its finalizers.

Each failure is either joined or reported, exactly once. A failure is reported
when nothing can join it any more: when its handle is dropped, or a join that
did not take the outcome, such as a canceled one, is dropped; if the child is
still running then, it is reported when the child completes. An unjoined
success is destroyed. The reporter is `IORuntimeConfig.reporter`, a host
function taking one formatted line: the errors when `E` is `Writable`,
otherwise their count and type. It writes to standard error by default, and
`report_unhandled_fiber_errors = False` turns reporting off. A fiber that
joins its own handle aborts; longer join cycles are not detected.

Fibers run on the host thread. The entered `IO` that starts the first fiber
hosts every fiber started beneath it, including fibers started by fibers, so
nesting costs no native stack; each root poll alternates whether that `IO`'s own
program or its fibers run first, sharing one transition budget.

`io.race_pair(other)` starts both as fibers and completes when the first
finishes, producing a `RaceWinner` with that side's outcome and the other side's
fiber, which stays a child of the running fiber; it is joined, canceled, or
drained like any other. `both`, `race`, `race_first`, and the timeouts are built
the same way, so one owner drains every child.

`Supervisor[E].scoped(body)` runs `body` with a `Supervisor` whose
`supervise(io)` starts fibers owned by the supervisor rather than by the fiber
that calls it, so they can outlive that fiber. When the body ends, a masked
release cancels the supervised fibers that are still live and waits for them,
as Cats Effect does by default; `await_on_release=True` waits for them to
finish instead. Supervising after release aborts.

`Driver.fibers()` lists the root `IO`'s live fibers between polls, like Cats
Effect's fiber dump: each `FiberInfo` names an internal slot, its owner's slot
(0 is the root program), and a `FiberStatus` of runnable, suspended, or draining
its children. It holds no payloads or completed fibers. Slots are reused, so an
index is not an identity, and fibers hosted by an `IO` lifted into a leaf with
`IO.lift` are not listed.

## Write programs generic over the family

Generic code can ask for only the effect capabilities it uses, as Cats Effect's
type classes do. Each capability is a compile-time dictionary that forwards to
an existing operation:

| Capability | Operations | Providers |
|---|---|---|
| `Defer` | `delay[I](f)`, `defer[I](factory)` | `Async[E]`, `SyncIO[E]` |
| `Raise` | `raise_error[I, A](e)` | `Async[E]`, `SyncIO[E]` |
| `Cancel` (`MonadCancel`) | `canceled[I]()`, `guarantee[I]`, `on_cancel[I]`, `guarantee_case[I]`, `uncancelable[I]`, `restore[I]` | `Async[E]`, `SyncIO[E]` |
| `Spawn` (`GenSpawn`) | `start[I]`, `join[I, T]`, `cancel[I, T]`, `never[I, A]`, `cede[I]` | `Async[E]` |

`Async[E]` is the dictionary for `IO[T, E]`; `SyncIO[E]` is the dictionary for
the synchronous `fp.effects.IO[E]`, which has no fibers. A function such as
`def protect[I: Defer & Cancel](...) -> I.Guaranteed[...] where ...` runs on
either provider; a provider without a capability is rejected at the call.
Associated types name each provider's carriers, so a generic signature states
its admission in `where` clauses, as other capabilities in `fp.effects` do.
`raise_error` builds a failure that recovery handles, never one marked
canceled. Generic entry points share the names of the synchronous functions and
take the dictionary as their first explicit parameter.

Transformer layers forward these capabilities through explicit selections, as
`LiftAsk` does for `Ask`. `LiftDefer[Layer, C]` and `LiftRaise[Layer, C]` lift
the base's carriers through any layer; `LiftCancel[Layer, C]` and
`LiftSpawn[Layer, C]` forward through `OptionalT` and `ResultT`, whose programs
are the base's programs:

```text
comptime Opt = OptionalT[Async[Int]]
var noted = delay[LiftDefer[Opt, Async[Int]]](Note())
var program = guarantee[LiftCancel[Opt, Async[Int]]](lookup(), noted^)
```

The layer's own absence or stored error is a base success: it runs `guarantee`
finalizers and is not a cancellation. Finalizers are the layer's unit programs,
their results discarded, and `guarantee_case` takes the base's case finalizer.
A fiber started through `LiftSpawn[OptionalT[Async[E]], Async[E]]` is a
`Fiber[Optional[T], E]`, and joining it produces absence inside a successful
`Outcome`. `ReaderT` and `StateT` forward only `Defer` and `Raise`; over `Async`,
a `ReaderT` bind, and so `defer`, is rejected when run, because the IO would
keep the borrowed environment.

## Drive external work and shutdown

`Driver` is a linear root owner. Poll it until `Progress.completed`, then consume
`finish()`. `request_cancel()` requests cancellation; continue polling to join
entered work and masked cleanup. No detach or abandoning destructor exists.
Negative poll budgets raise setup `Error` before advancing work and leave the
owner usable; catch that error while retaining the driver. A zero budget only
observes. The nonraising `poll()` overload uses a budget of 64.

`IORuntimeConfig` sets how much `IO` work one root poll runs and how often the
run loop checks for cancellation; pass it to `Driver(program, token, clock,
config)` or `run(program, config)`. The defaults match the existing behavior:
`auto_yield_threshold` is 1,024 transitions per root poll and
`cancelation_check_threshold` is 1, a check at every bind and recovery handoff.
Both thresholds must be positive, and the yield threshold must be a multiple of
the check threshold; otherwise construction raises setup `Error`.

A transition is evaluating a head, applying a bind, map or recovery, unwinding a
finalizer or region exit, or polling a leaf. A leaf poll that runs nested `IO`
counts their transitions instead of its own. Every `IO` run loop under one root,
including the children of `both`, `race` and resources, draws from one budget
per root poll and yields with a runnable wait when it is spent. Masked cleanup
yields too, without becoming cancelable. The body of a native callback, a
custom `Machine.poll`, and destructors are not counted and cannot be preempted.

`Progress.transitions` reports the transitions a `poll` spent, and
`Progress.quiescent` reports a program that is neither completed nor runnable
and has no live deadline, so it awaits external input. With an
`auto_yield_threshold` of 1, `Driver.poll(1)` runs one transition, which steps a
program in tests on the same engine. Treat quiescence as deadlock only when no
input will arrive.

`IO.async(register, withdrawal)` owns withdrawal after every entered
registration, including successful completion and registration failure;
`IO.async_` has none. Copies of `Completion` share one decision; late or
duplicate payloads are rejected. Delivery remains a cooperative host-thread
operation. `timeout_to` requests cancellation and drains the source before
selecting a surviving source outcome or fallback. A timeout cannot force masked
work or cleanup to stop.

<!-- example: docs/examples/async_callback_timeout.mojo -->

`Duration` checks nonnegative integer nanoseconds, milliseconds, or seconds
before multiplication, up to 10**18 nanoseconds. `Instant` is an opaque absolute
point: compare points within one clock origin and add a checked duration using
`after` or `+`. `Clock.now()`, `Context.now()`, `Wait.until`, and
`Progress.deadline` share that type throughout the scheduler. Timer entry beyond
`Int.MAX` and carry between counter words preserve live deadlines.

Manual clock copies share synchronized time. `Clock.manual(initial)` accepts a
nonnegative `Int`; `advance_to(instant)` rejects backward updates and system
clocks with native setup `Error`, leaving state unchanged. These setup errors
are separate from the program's domain error `E`.

<!-- example: docs/examples/async_host_cancel.mojo -->

`run` blocks until self-contained work drains, using the existing idle sleep
fallback. Use `Driver` when the host must deliver events or advance manual time.
A pending driver with no runnable work may require an external signal or its
reported deadline.

## Cats and Cats Effect mapping

| Scala concept | Mojo spelling | Contract |
|---|---|---|
| `IO[A]` | `IO[T, E]` | Exact domain error; one value runs once |
| `IO.pure`, `IO.delay`, `IO.defer`, `IO.raiseError` | `IO[T, E].pure`, `.delay`, `.defer`, `.raise_error` | `defer` builds recursive programs lazily |
| `flatMap`, `map`, `tailRecM` | `flat_map`, `map`, `tail_rec_m[Async[E]]` | Constant native stack |
| `attempt`, `handleErrorWith` | `attempt`, `handle_error_with` | Complete failures; mixed cancellation bypasses recovery |
| `guarantee`, `guaranteeCase`, `onCancel`, `uncancelable` | `guarantee`, `guarantee_case`, `on_cancel`, `IO.uncancelable` | Masked cleanup with the exact exit |
| `IO.async`, `IO.async_` | `IO.async`, `IO.async_` | Withdrawal runs after every entered registration |
| `IO.cede`, `IO.never`, `IO.sleep`, `IO.canceled` | the same, on `IO[T, E]` | |
| `both`, `race`, `timeoutTo` | `both`, `race`, `timeout_to` | Cancel and drain; surviving source outcomes can win |
| Earlier selection policies | `race_first`, `timeout_after` | First terminal outcome, or timer-selected fallback after clean draining |
| `Resource.make`, `makeCase`, `use` | `Resource.make`, `make_case`, `use`, `use_scoped` | Scoped borrowing; reverse release order |
| `MonadCancel`, `GenSpawn`, `Sync` (deferral only) | `Cancel`, `Spawn`, `Defer`, `Raise` dictionaries: `Async[E]`, `SyncIO[E]` | Narrower capabilities stay narrower; the synchronous family has no `Spawn` |
| `MonadCancel[OptionT[F, *], E]` and the other transformer instances | `LiftDefer`, `LiftRaise`, `LiftCancel`, `LiftSpawn` selections | Cancel and Spawn forward through `OptionalT` and `ResultT` only; case finalizers observe the base exit |
| `fa.start`, `fiber.join`, `fiber.cancel` | `io.start()`, `fiber^.join()`, `fiber.cancel()`, `fiber.request_cancel()` | Owners drain unjoined children before completing |
| `Supervisor(await).use(f)`, `supervise` | `Supervisor[E].scoped(f, await_on_release)`, `supervisor.supervise(io)` | Release cancels live supervised fibers unless it awaits them |
| `racePair` | `io.race_pair(other)` | A `RaceWinner` with the first outcome and the other fiber |
| `joinWith`, `joinWithNever`, `joinWithUnit` | `join_with`, `join_with_never`, `join_with_unit` | A canceled child runs the fallback, waits, or produces unit |
| `IORuntimeConfig` | `IORuntimeConfig(cancelation_check_threshold, auto_yield_threshold)` | Same validation; by default checks every bind, where Cats Effect checks every 512, and yields every 1,024 transitions |
| `reportUnhandledFiberErrors`, `reportFailure` | `IORuntimeConfig.report_unhandled_fiber_errors`, `.reporter` | On by default; reports when the last handle or join is dropped |
| Fiber dump | `Driver.fibers()` returning `FiberInfo` | Live fibers of the root, with owner and status, no payloads |

Operations use snake_case. Types follow the repository's Mojo class convention.
`async` is declared with backticks because it is a Mojo keyword, and called as
`IO[T, E].async(...)`. `Async[E]` supplies sequencing and error recovery; it is
not the full Cats Effect `Async[F]` hierarchy. Queue values are FIFO, with no
waiter fairness promise. Public type parameters and documented metadata are
supported; compiler type spellings, storage, ABI, allocation counts, and
compilation complexity are not stability promises.

### Migrating from recipes

Earlier previews exposed one concrete recipe type per operation. Every
operation now returns `IO`:

| Before | Now |
|---|---|
| `Pure[T, E]`, `pure[E](value)` | `IO[T, E]`, `IO[T, E].pure(value)` |
| `delay[E](f)`, `eval_io(program)` | `IO[T, E].delay(f)`, `IO[T, E].eval_io(program)` |
| `raise_error[E, T](e)`, `handle_error_with(p, h)`, `attempt(p)` | `IO[T, E].raise_error(e)`, `p.handle_error_with(h)`, `p.attempt()` |
| `both(l, r)`, `race(l, r)`, `race_first(l, r)` | `l.both(r)`, `l.race(r)`, `l.race_first(r)` |
| `timeout_to(p, d, f)`, `timeout_after(p, d, f)`, `sleep[E](d)` | `p.timeout_to(d, f)`, `p.timeout_after(d, f)`, `IO[NoneType, E].sleep(d)` |
| `guarantee(p, c)`, `on_cancel(p, c)`, `guarantee_case(p, f)` | `p.guarantee(c)`, `p.on_cancel(c)`, `p.guarantee_case(f)` |
| `uncancelable(p)`, `uncancelable_with[E](f)` | `IO[T, E].uncancelable(f)`; `f` receives a `Poll[E]` it may ignore |
| `callback(register, withdrawal)` | `IO[T, E].async(register, withdrawal)` |
| `resource(acquire, release)`, `use(body)` | `Resource[T, E].make(acquire, release)`, `use(body)` |
| `resource_case(acquire, cleanup)`, `use(scoped_body)` | `Resource[T, E].make_case(acquire, cleanup)`, `use_scoped(scoped_body)` |
| `Deferred`, `Queue`, `Semaphore` operations | the same names, returning `IO` |
| A custom `Machine` with `Family = Async[E]` | A `Machine`, lifted with `IO[T, E].lift(machine)` |
| `Nursery`, `Spawner`, `scope`, `ScopedBoth` | Removed; start fibers with `io.start()` and join them |

## Extension and accelerator boundary

A custom `Machine` declares `Value` and `Error`, then returns `Step.ready` or
`Step.pending` from each cooperative poll; `IO[T, E].lift` runs it as one step
of an `IO`. Read a `Signal` revision before inspecting readiness, then use
`Wait.changed` with that revision if still pending. Registration preserves
intervening notification. Use `context.now() + duration` with `Wait.until` for a
timer. Scheduler storage, mask markers, raw tasks, and child polling remain
internal.

A terminal step certifies that entered work and cleanup finished, or ownership
transferred into the result. Device submission alone is not completion.
Future accelerator leaves can retain buffers and access rights, batch external
work, and report readiness through the host. They must perform their own device
synchronization and drain in-flight work before release. This architecture has
no identified fundamental obstacle to host GPU orchestration; GPU execution and
foreign-thread completion bridges are not implemented or qualified here.

Focused source/package checks at O0/O3 cover the preview. The completed
[overnight qualification](../architecture/async-qualification.md#overnight-results)
adds twelve one-hour stress cases, retained-storage checks, and separate local
performance measurements. The runtime remains an opt-in preview on the pinned
Linux x86-64 toolchain.

The [advanced development plan](../architecture/async-advanced-plan.md) covers
lightweight fibers and generic effect capabilities. Concurrent collection
operations remain deferred.
