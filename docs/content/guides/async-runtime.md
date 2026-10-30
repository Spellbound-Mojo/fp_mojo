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
own their state. `IO`'s methods, `Pipeline`, `tail_rec_m`, the free `map`,
`flat_map`, and `traverse`, and `fp.iteration`'s `traverse` and `traverse_void`
copy plain functions and accept library callables that own their state.
Capturing closures and borrowed callback views are rejected at compile time.
The other free `fp.iteration` traversals, folds, and searches still borrow
plain functions, so with `IO` they take an owned library callable, such as
`as_unary(f)` for a unary callback. A callable struct holding a pointer cannot
be detected and must not outlive what it points to. Raising native callbacks keep
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

## Drive external work and shutdown

`Driver` is a linear root owner. Poll it until `Progress.completed`, then consume
`finish()`. `request_cancel()` requests cancellation; continue polling to join
entered work and masked cleanup. No detach or abandoning destructor exists.
Negative poll budgets raise setup `Error` before advancing work and leave the
owner usable; catch that error while retaining the driver. A zero budget only
observes. The nonraising `poll()` overload uses a budget of 64.

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
| `Fiber.cancel` | `request_cancel`, poll, `finish` | Request plus explicit complete draining |

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
| `Nursery`, `Spawner`, `scope`, `ScopedBoth` | Removed; fibers with `start` and `join` follow in Pass 9 |

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
