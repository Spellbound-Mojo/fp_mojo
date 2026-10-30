# Async runtime preview

`fp.effects.async_runtime` provides pure-Mojo asynchronous composition over
explicit state machines. This opt-in preview is qualified on the pinned Mojo
1.2.0 Linux x86-64 checkout. It executes cooperatively on one host thread.
Callbacks must return promptly; `delay` and `eval_io` perform synchronous work
inside their poll. The preview does not offload blocking IO or use compiler
coroutines.

Import application operations from `fp.effects.async_runtime`, preferably as
`ar` when synchronous effects are also in scope. Custom leaf and scoped-body
contracts live in `fp.effects.async_runtime.protocols`. Canonical `Outcome`,
`EffectFailure`, `ExitCase`, `CancellationToken`, and `Permit` stay in
`fp.effects`; `pipeline` and `tail_rec_m` retain their existing import paths.
See the [application reference](../reference/effects.async_runtime.md) and
[extension reference](../reference/effects.async_runtime.protocols.md).

## Sequence and iterate

Recipes own one execution. Constructing a recipe invokes no user callback.
`pure` owns an already evaluated value, while `delay` defers its callback.
Unopened recipes may be discarded; repeating work constructs a fresh recipe.
`pipeline` selects `Async[E]` using machine metadata. Its `flat_map` is sequential;
use `both` to own concurrent children.

<!-- example: docs/examples/async_sequencing.mojo -->

Use `tail_rec_m` for iterative work. Each step consumes its state and returns
`ControlFlow`: `Continue` transfers the next state and `Break` transfers the
result. The runtime retains one active iteration and yields between steps.
Arbitrarily nested concrete bind types have no blanket compilation-cost or
stack-depth guarantee.

<!-- example: docs/examples/async_iteration.mojo -->

Native callbacks retain their exact error and origin requirements. Leaf
constructors select `E` explicitly; composite operations infer it and require
matching domain errors. New owned constructors consume their callbacks.
Existing Pipeline closure overloads borrow callbacks through execution; move an
`as_unary(callback^)` adapter when transferring a callback into the recipe.
Raising native Pipeline callbacks select `.raising[E]()`.

## Own resources and failures

Resources compose acquisition and release in one owned scope. Dependent
resources release in reverse order. A native resource factory borrows the
resource only while building an independently owned recipe; it cannot return a
machine retaining that temporary loan. Implement `ScopedMachine` when the body
needs a fresh resource loan on each poll, or `CleanupMachine` when release also
needs the exact exit case.

<!-- example: docs/examples/async_resources.mojo -->

`handle_error_with` consumes the complete noncanceled `EffectFailure[E]` and
builds a replacement. `attempt` materializes ordinary failure as a `Result`.
Cancellation-only outcomes and failures with a cancellation flag bypass both
recovery operations. Full ordered errors remain available through canonical
`fold_outcome`.

<!-- example: docs/examples/async_error_recovery.mojo -->

Generic wrappers can name `Pure`, `Bind`, `Loop`, `NativeDelay`, resource recipe
aliases, and handle-associated results. `ResourcePlan` and
`AsyncResource[P].MapCompatible`, `UseCompatible`, and `BindCompatible` preserve
native admission without exposing acquisition or release ownership. Family
wrappers use existing public algebra contracts such as `BindContract`,
`TailRecContract`, and `AttemptContract`.

## Drive external work and shutdown

`Driver` is a linear root owner. Poll it until `Progress.completed`, then consume
`finish()`. `request_cancel()` requests cancellation; continue polling to join
entered work and masked cleanup. No detach or abandoning destructor exists.
Negative poll budgets raise setup `Error` before advancing work and leave the
owner usable; catch that error while retaining the driver. A zero budget only
observes. The nonraising `poll()` overload uses a budget of 64.

`callback(register, withdrawal)` owns withdrawal after every entered
registration, including successful completion and registration failure. Copies
of `Completion` share one decision; late or duplicate payloads are rejected.
Delivery remains a cooperative host-thread operation. `timeout_to` requests
cancellation and drains the source before selecting a surviving source outcome
or fallback. A timeout cannot force masked work or cleanup to stop.

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
reported deadline. Nursery capacity is a bound on lifetime accepted children,
not on reusable concurrent slots; rejected submissions return the owned child.

## Cats and Cats Effect mapping

| Scala concept | Mojo spelling | Contract |
|---|---|---|
| `flatMap`, `tailRecM` | `flat_map`, `tail_rec_m` | Selected native family, concrete owned recipes |
| `Resource.make` | `resource`, `resource_case` | Structured release; scoped borrowing is fresh per poll |
| `attempt`, `handleErrorWith` | `attempt`, `handle_error_with` | Complete failures; mixed cancellation bypasses recovery |
| `race`, `timeoutTo` | `race`, `timeout_to` | Cancel and drain; surviving source outcomes can win |
| Earlier selection policies | `race_first`, `timeout_after` | First terminal outcome, or timer-selected fallback after clean draining |
| `Fiber.cancel` | `request_cancel`, poll, `finish` | Request plus explicit complete draining |
| Reusable `IO[A]` | A factory constructing a new recipe | Native ownership permits move-only captures and results |

Operations use snake_case. Types follow the repository's Mojo class convention.
`Async[E]` supplies sequencing and error recovery; it is not the full Cats Effect
`Async[F]` hierarchy. Queue values are FIFO, with no waiter fairness promise.
Public type parameters and documented metadata are supported; compiler type
spellings, storage, ABI, allocation counts, and compilation complexity are not
stability promises.

## Extension and accelerator boundary

A custom `Machine` declares `Value`, `Error`, and `Family = Async[Error]`, then
returns `Step.ready` or `Step.pending` from each cooperative poll. Read a
`Signal` revision before inspecting readiness, then use `Wait.changed` with
that revision if still pending. Registration preserves intervening notification.
Use `context.now() + duration` with `Wait.until` for a timer. Scheduler storage,
mask markers, raw tasks, and child polling remain internal.

A terminal step certifies that entered work and cleanup finished, or ownership
transferred into the result. Device submission alone is not completion.
Future accelerator leaves can retain buffers and access rights, batch external
work, and report readiness through the host. They must perform their own device
synchronization and drain in-flight work before release. This architecture has
no identified fundamental obstacle to host GPU orchestration; GPU execution and
foreign-thread completion bridges are not implemented or qualified here.

Focused source/package checks at O0/O3 cover the preview. Sustained stress,
performance, and retained-storage qualification remain deferred to the agreed
future overnight work.
