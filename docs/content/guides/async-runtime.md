# Async runtime guide

`fp.effects.async_runtime` provides pure-Mojo asynchronous programs with Cats
Effect vocabulary: `IO`, `Resource`, `Ref`, `Deferred`, `Queue`, `Semaphore`,
races, and timeouts. It is qualified with Mojo 1.2.0 on Linux x86-64 and macOS
arm64. By default it runs fibers in parallel on a work-stealing
pool, with one worker per logical processor; the current-thread profile runs
them cooperatively on one thread (see
[run programs on a runtime](#run-programs-on-a-runtime)). Callbacks must
return promptly; `IO.delay` and `IO.eval_io` perform synchronous work inside
their step. Blocking work belongs in `IO.blocking` or `IO.interruptible`, which
run it on a pool of worker threads (see
[run blocking calls](#run-blocking-calls)). The runtime does not use compiler
coroutines. Code written for an earlier preview, or for the current-thread
default it had, can follow the [migration guide](async-migration.md).

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
`report_unhandled_fiber_errors = False` turns reporting off. A custom reporter
may be called from any thread that settles a fiber, and from several at once
once fibers run in parallel, so it must be safe there; lines written by
concurrent calls may interleave. A fiber that
joins its own handle aborts; longer join cycles are not detected.

Each fiber, like the root program, is a task of the root's scheduler: it runs
when something it waits for wakes it, and nesting costs no native stack. On
the current-thread profile every fiber runs on the root's thread and each root
poll runs the ready tasks in turn, sharing one transition budget; on the
work-stealing profile ready fibers run in parallel on the pool's workers, each
with its own transition budget, refilled whenever a worker runs it.

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
finish instead. Release first closes the supervisor: a `supervise` that loses
the race with release, or runs after it, returns a fiber that is already
canceled. Its program never runs, and joining it yields a cancellation, as
starting observes cancellation elsewhere.

<!-- example: docs/examples/async_fibers.mojo -->

`Driver.fibers()` lists the live fibers under the root between polls, like Cats
Effect's fiber dump: each `FiberInfo` names an internal slot, its owner's slot
(0 is the root program), and a `FiberStatus` of runnable, suspended, or draining
its children. It holds no payloads or completed fibers. Slots are reused, so an
index is not an identity. Fibers started by an `IO` lifted into a leaf with
`IO.lift` are listed under the fiber running that leaf.

## Run a collection concurrently

`par_traverse(source, f)` runs every element's IO as a child fiber of the
running fiber, Cats Effect's `parTraverse`; `par_sequence(programs)` runs a
source of IOs the same way. Both take the family as `I`, any family whose
conformance includes `Parallel`, inferred from the callback's result: `Async[E]` has `Par = AsyncPar[E]`, Cats Effect's
`IO.Par`, an applicative over the same `IO` carriers whose combination and
traversal run concurrently. `par_traverse` is `traverse` with that family, so
the source keeps its shape and every native-callback form is accepted, except
closures, which `IO` rejects as it does everywhere. `SyncIO[E]` has no
`Parallel` and is rejected. The parameter is `I: Functor` with
`where conforms_to(I, Parallel)`, not `I: Parallel`, so that a layer whose
`Parallel` is conditional, such as `OptionalT[Async[E]]`, can be named as
written. The fluent `par_traverse` and `par_sequence` on `Pipeline` and `Iter`
select `AsyncPar[E]` for `IO` callbacks, and `par_map_n` and `par_product_n`
select the pipeline's family's `Par`, which is `AsyncPar[E]` for an `IO`
pipeline; a `Result` callback or operand keeps error-accumulating validation. `fp.iteration` adds `par_traverse_void`, which
keeps no results.

```text
from fp.algebra import par_traverse, par_traverse_n

def fetch(var id: Int) -> IO[Page, Error]   # a plain function

var pages = par_traverse(ids^, fetch)          # IO[List[Page], Error]
var gentle = par_traverse_n(8, ids^, fetch)    # at most 8 requests at once
```

The contract follows `both`:

- **Order.** The callback runs on the running fiber, in source order, when the
  IO runs. Results keep source order.
- **Failure.** The first element that ends unsuccessfully stops the others.
  Every started child finishes, cleanup included, before the IO completes, and
  the failure carries every error observed by then, in element order rather
  than in time order. Cats Effect reports only the first. A child stopped
  before it first ran runs nothing, not even its finalizers, and the failure
  records the cancellation. An error the callback raises takes its element's
  place. Elements not yet pulled are never started.
- **Cancellation.** Canceling the program forwards the request to every child
  and completes only after all of them finish; the program then completes
  canceled, or with the failures observed while draining. An outer
  `uncancelable` still masks it.
- **Empty sources** complete with an empty result and start no fiber.

<!-- example: docs/examples/async_par_traverse.mojo -->

`par_traverse_n(limit, source, f)`, `par_sequence_n` and
`par_traverse_void_n` run at most `limit` elements at once, Cats Effect's
`parTraverseN` with a live limit instead of a semaphore: a finished element
frees its place for the next, so at most `limit` children are live for a
source of any length. A finished value waits for the elements before it, so a
slow early element holds the values that finished after it; `_void_n` keeps
none. `limit = 1` behaves as `traverse`, in outcome and in effect order. A
limit below one aborts at the call. These take owned iterables and iterators
and produce a `List`.

Each element costs about one fiber start, around 5 µs, about the cost of a
bare `start` and `join`; a sequential `traverse` costs about 70 ns per element.
Use concurrent traversal when an element waits or works for at least tens of
microseconds, and batch smaller elements into one element per batch. On the
work-stealing profile, the default, CPU-bound elements run in parallel; on the
current-thread profile waits overlap and CPU-bound work does not. The calls are
the same on both.

### Through OptionalT and ResultT

`OptionalT[Async[E]]` and `ResultT[Async[E], S]` provide `Parallel`, so name
the layer to traverse with its semantics:

```text
var found = par_traverse[OptionalT[Async[Error]]](ids^, lookup)   # IO[Optional[List[Page]], Error]
var both = pipeline[ResultT[Async[Error], String]](a^).par_product_n((b^,)).get()
```

These follow Cats' `Parallel` for `OptionT` and `EitherT`, and they differ from
the sequential `traverse` through the same layer: **absence and stored errors
do not short-circuit.** Every element runs to completion, its effects and
finalizers included, and only then is the result absent, or the first stored
error in element order. An element absent at once does not stop a slower
element after it. A failed or canceled `IO`, which is not a layer value, still
stops and drains the others as above. The bounded forms and
`par_traverse_void` behave the same way, and `par_map_n` and `par_product_n`
run both sides. Without a named layer, `par_traverse` over callbacks returning
`IO[Optional[A], E]` uses `Async[E]` and produces `IO[List[Optional[A]], E]`, as
`traverse` does.

`ReaderT`, `StateT` and `WriterT` have no `Parallel` and are rejected: a
reader's environment cannot live inside each child, states cannot merge, and a
log is lost on failure. Run the layer first, then traverse its `IO`
concurrently.

## Write programs generic over the family

Generic code can ask for only the effect capabilities it uses, as Cats Effect's
type classes do. Each capability is a compile-time dictionary that forwards to
an existing operation:

| Capability | Operations | Providers |
|---|---|---|
| `Defer` | `delay[I](f)`, `defer[I](factory)` | `Async[E]`, `SyncIO[E]` |
| `Raise` | `raise_error[I, A](e)` | `Async[E]`, `SyncIO[E]` |
| `Cancel` (`MonadCancel`) | `canceled[I]()`, `guarantee[I]`, `on_cancel[I]`, `guarantee_case[I]`, `uncancelable[I]`, `restore[I]` | `Async[E]`, `SyncIO[E]` |
| `Spawn` (`GenSpawn`) | `start[I]`, `join[I, T]`, `cancel[I, T]`, `never[I, A]`, `cede[I]`, `background[I]` | `Async[E]` |
| `Concurrent` (`GenConcurrent`) | `make_ref[I]`, `get_ref[I, T]`, `set_ref[I]`, `update_ref[I]`, `modify_ref[I, A]`, `make_deferred[I, T]`, `complete_deferred[I]`, `get_deferred[I, T]` | `Async[E]` |
| `Timing` (`Clock`) | `monotonic[I]()`, `real_time[I]()`, `timed[I](program)` | `Async[E]`, `SyncIO[E]` |
| `Temporal` (`GenTemporal`) | `sleep[I]`, `timeout_to[I]`, `timeout_after[I]`, `timeout[I]`, `delay_by[I]`, `and_wait[I]` | `Async[E]` |
| `Blocking` (`Sync`'s `blocking`, `interruptible`) | `blocking[I](f)`, `interruptible[I](f)` | `Async[E]` on the blocking pool, `SyncIO[E]` inline |
| `EvalOn` (`Async`'s `evalOn`, `startOn`, `backgroundOn`, `executionContext`) | `eval_on[I](program, target)`, `start_on[I](program, target)`, `background_on[I](program, target)`, `execution_context[I]()` | `Async[E]`, with `ExecutionContext` targets |

`Async[E]` is the dictionary for `IO[T, E]`; `SyncIO[E]` is the dictionary for
the synchronous `fp.effects.IO[E]`, which has no fibers. A function such as
`def protect[I: Defer & Cancel](...) -> I.Guaranteed[...] where ...` runs on
either provider; a provider without a capability is rejected at the call.
Associated types name each provider's carriers, so a generic signature states
its admission in `where` clauses, as other capabilities in `fp.effects` do.
`raise_error` builds a failure that recovery handles, never one marked
canceled. Generic entry points share the names of the synchronous functions and
take the dictionary as their first explicit parameter.

`Concurrent`'s handles are `Ref` and `Deferred`. A `Ref` is a shared cell whose
updates run once under its guard, never suspend, and so are atomic with respect
to other fibers; `get`, `get_and_update`, and `update_and_get` copy the state,
while `modify`, `update`, `set`, `get_and_set`, and `inspect` also work for
move-only state. Updates cannot raise, because consuming the old state would
lose it on failure. A `Deferred` is completed once, and every waiting reader
receives a copy. `make_ref` and `make_deferred` create fresh state each time a
program runs. Its entry points carry the handle in their names because `ref` is
a Mojo keyword and `get`, `put`, and `modify` already select `Stateful` state.
Callbacks given to either handle are library callables or plain functions;
closures are rejected, as for other `IO` callbacks.

<!-- example: docs/examples/async_coordination.mojo -->

Time comes from one clock per root: every fiber, sleep, timeout, and
`monotonic` reading in a driven program uses the system monotonic clock or the
manual clock given to its `Driver`, which moves only when advanced. An
`Instant` is compared only within that clock, and `later.since(earlier)` gives
the `Duration` between two readings; `to_nanoseconds()` reads a duration.
`timed` pairs that duration with a program's value, and a failure has none.

<!-- example: docs/examples/async_capabilities.mojo -->

Wall-clock time is separate. `real_time[I]()` and `IO[T, E].real_time()` read
a `SystemTime`, signed nanoseconds since the Unix epoch, like Rust's
`SystemTime` beside its `Instant` and Cats Effect's `Clock.realTime`. The
system clock reads `CLOCK_REALTIME`, which moves backward when the system time
is set, so a `SystemTime` is never an `Instant` and elapsed time belongs to
`monotonic`: `later.since(earlier)` returns `None` when the wall clock stepped
back, where `Instant.since` cannot go backward. `SystemTime.seconds(n)` and
`.nanoseconds(n)` build one and `to_seconds()` (rounding down) and
`to_nanoseconds()` read it; adding or subtracting a `Duration` raises outside
the supported years 1677 to 2262, and it writes as RFC 3339 UTC, such as
`2023-11-14T22:13:20Z`, with nine fractional digits when they are not all
zero. A manual clock drives both readings: its wall time is the epoch plus its
monotonic reading, so under `TestControl` `real_time` starts at
`1970-01-01T00:00:00Z` and moves with virtual time, as in Cats Effect.

`SyncIO` provides `Timing` but not `Temporal`: the synchronous
`sleep_io` blocks the thread on the system clock, and inside an `IO` through
`IO.eval_io` it blocks the cooperative host.

Transformer layers forward these capabilities through explicit selections, as
`LiftAsk` does for `Ask`. `LiftDefer[Layer, C]`, `LiftRaise[Layer, C]`,
`LiftTiming[Layer, C]`, and `LiftBlocking[Layer, C]` work through any layer; `LiftCancel`, `LiftSpawn`,
`LiftConcurrent`, `LiftTemporal`, and `LiftEvalOn` forward through `OptionalT` and
`ResultT`, whose programs are the base's programs:

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
`Outcome`. A cell made through `LiftConcurrent` is the base's cell. Timeouts
forward the layer's programs, so a layer's absence beats the deadline, while
`timed`, `delay_by`, and `and_wait` bind through the layer, as Cats Effect
derives them: a layer's absence has no duration and skips the sleep after it.
`ReaderT`, `StateT`, and `WriterT` forward only `Defer`, `Raise`, and `Timing`;
over `Async`, a `ReaderT` bind, and so `defer` and `timed`, is rejected when
run, because the IO would keep the borrowed environment.

## Run blocking calls

`IO[T, E].blocking(f)` runs an owned function on a worker thread and resumes the
fiber with its result or error; other fibers of the root keep running
meanwhile. Like Cats Effect's `IO.blocking`, the call cannot be canceled: a
cancellation or a timeout waits for the function to return, and `timeout_to`
then prefers its drained result. The function follows the `IO` callback rule:
a library callable such as a `OnceThunk`, or a plain `def() thin` function, with
error `E` or none. Closures are rejected.

`IO[T, E].interruptible(f)` lends the function an `Interruption` handle for the
call. `requested()` reports whether the fiber's cancellation was requested, and
a request stays visible, so there is no separate `interruptibleMany`. On
cancellation the call completes when the function returns; its late result is
then rejected and destroyed on the worker thread, and the fiber is canceled.
`sleep(duration)` waits through the handle and returns False as soon as the
request arrives, True when the duration elapsed.
`await_readable(fd, timeout)` and `await_writable(fd, timeout)` wait for a
`RawFileDescriptor` the caller owns and keeps open: they return True when it is
ready, hang-up and error conditions included, and False when the request
arrives or the optional timeout expires, which `requested()` tells apart; a
`poll` failure raises `OSError`. No POSIX signal is sent, as in
Cats Effect on Scala Native: a function blocked in an operating-system call
that does not go through the handle is not woken.
The handle is neither copyable nor movable, and the function receives it
borrowed, so it cannot outlive the call.

<!-- example: docs/examples/async_blocking.mojo -->

**The caller's obligation.** The function, its result and its error move to a
worker thread and back, and may be destroyed on either: on the worker when a
late result is rejected, or when the function is consumed. Mojo has no `Send`
or `Sync` proof, so the caller asserts that these values may move to, be used
on, and be destroyed on another thread, as for `unsafe_start` and
`Completion.complete` (see [share state across threads](#share-state-across-threads)).
Share mutable state with the function only through atomics or the
library's synchronized owners.

Calls run on a `BlockingPool`, after Cats Effect's blocking execution context
and Erlang's dirty I/O schedulers. Workers start on demand, an idle worker is
reused for the next call and retires after `idle_timeout`, and at most
`max_workers` run at once; further calls wait in a queue.
`BlockingPool(max_workers=64, idle_timeout=60 s)` raises for a nonpositive
maximum. Each root uses `IORuntimeConfig.blocking_pool`, or else a private pool
with the defaults, created on the root's first blocking call, so a root that
never blocks pays nothing for it. Copies of a pool share it, so passing one pool to several roots
shares its workers:

```text
var config = IORuntimeConfig()
config.blocking_pool = Optional(BlockingPool(8, Duration.seconds(5)))
var outcome = run(program^, config)
```

A pool lives as long as its copies. Finishing a root waits for its calls, then
drops its copy; when the last copy is dropped, the pool waits for its queued
and running calls, then stops and joins its workers. A pool whose last copy is
dropped on one of its own workers lets that worker exit on its own. A blocking
call outside a `Driver`, `run`, or `TestControl` aborts.

**On the work-stealing profile** (the default on more than one processor), a root with no
configured pool does not queue its calls. The worker running the fiber hands
its queue of fibers to a replacement thread and runs the call on the thread
that made it, as Cats Effect's `prepareForBlocking` does, so other fibers keep
running without a trip through another thread's queue. Afterwards the thread
offers itself for reuse and retires after 60 seconds idle. At most 64 calls
are handed off at once; further calls queue on the root's private pool, so
the thread count stays bounded. `interruptible` hands off the same way, and
its handle's waits wake on cancellation as on the blocking pool. A configured
`IORuntimeConfig.blocking_pool` is always honored: its calls never hand off,
so a pool such as `BlockingPool(max_workers=1)` still runs one call at a time
on either profile. The caller's obligation above is unchanged: a call may run,
and its late result be destroyed, on a thread other than the one that later
resumes the fiber.

The synchronous family provides the same capability inline: `blocking[SyncIO[E]]`
runs the function like `delay`, on the calling thread, which the synchronous
family blocks anyway, and `interruptible[SyncIO[E]]` passes a handle that
reads the running program's cancellation token. Its `sleep` and descriptor
waits park in a poller of their own, which the token interrupts, so they return
False as soon as the request is made, before or during the wait. The
synchronous `sleep_io` parks the same way, and under a mask it sleeps its whole
duration.

To run a whole program on another thread pool, rather than one call, use
[execution contexts](#run-work-on-another-execution-context): `eval_on` a
`BlockingPool`. The [provider matrix](#provider-matrix) lists every operation
of Cats Effect's `Sync` and `Async`.

## Share state across threads

By default fibers run in parallel on the work-stealing profile
(`Profile.work_stealing`, see
[run programs on a runtime](#run-programs-on-a-runtime)), where a fiber can
park on one worker and resume on another, and values also cross threads
through blocking calls and `Completion.complete`. The contract below holds
for every program, on both profiles. The
[payload thread safety](../architecture/async-thread-safety.md) page has the
research and the audit of the runtime's own structures.

**What must be transferable.** Every value the runtime owns on a program's
behalf may move to another thread, be used there, and be destroyed there:

- everything stored in an `IO`: the callables given to `delay`, `map`,
  `flat_map`, `handle_error`, `guarantee` and the rest, the values given to
  `pure`, custom leaves, and the resources and finalizers of `Resource`;
- fiber state between steps: values bound by a continuation, an outcome
  waiting to be joined, the errors of a failure, a custom `Machine`;
- outcomes passed to `Completion.complete`, and the functions, results and
  errors of `IO.blocking` and `IO.interruptible`;
- values stored in `Ref`, `Deferred` and `Queue`.

Plain data (`Int`, `String`, `List`, `Dict`, `Optional` and structs of
these) and values owned uniquely through `OwnedPointer` are transferable when
their elements are. A raw `Pointer` whose target another thread may use or
free without synchronization, a borrowed view of another owner's state, and a
handle to a thread-local resource are not.

**How fibers share mutable state.** Only through the library's synchronized
owners (`Ref`, `Deferred`, `Queue`, `Semaphore`, `Completion`,
`CancellationToken`, `Fiber` handles, `Supervisor`), through types whose
authors synchronize them (an `Atomic`, or a structure behind a lock), or as
immutable data behind an `ArcPointer`. Callbacks that run under an owner's
lock, such as `Ref.modify`, must stay short and must not re-enter that owner.

!!! warning "An `ArcPointer` to mutable data is a data race"
    `ArcPointer` counts references atomically, but its target is not
    synchronized. Two fibers that each hold a copy and mutate the target
    (`arc[] += 1`, `arc[].append(x)`) race once they run on different workers.
    The `thread_arc_race` probe counted between 110,730 and 130,517 of 200,000
    increments made through two copies on two threads; with an
    `ArcPointer[Atomic[Int64]]` it counted all 200,000. Share a `Ref` instead,
    or an `ArcPointer` to atomics.

Code that keeps unsynchronized sharing can run on the current-thread profile,
which runs every fiber of the root on one thread, one setting away from the
work-stealing default: `config.profile = Profile.current_thread()`.

**What the compiler checks.** Mojo 1.2 has no `Send` or `Sync`, so the library
checks only what reflection can see. Every payload erased into an `IO`, a
fiber or a coordination owner passes one check: it is rejected when its field
tree reaches a raw or borrowed `Pointer` through a struct that does not
conform to `ThreadTransferable`:

```text
constraint failed: cannot erase `app.Raw`: it reaches a `Pointer` field of
`app.Raw`, which is not ThreadTransferable. An erased payload must own its
state and be safe to move to, use on and destroy on another thread. ...
```

`ThreadTransferable`, from `fp.effects`, is the author's explicit claim that
a type is safe anyway, such as a container that owns memory through a raw
pointer and never shares it, or a structure that synchronizes every access.
The check stops at a conforming type. Never claim it for a borrowed view.

```text
from fp.effects import ThreadTransferable, assert_thread_transferable

struct Counter(Movable, ThreadTransferable):
    # Every access to the shared target is atomic.
    var count: ArcPointer[Atomic[Int64]]
```

The check does not reject `ArcPointer`, because immutable sharing and shared
atomics are correct and common. `assert_thread_transferable[T]()` is stricter
and opt-in: it also rejects `ArcPointer` and `WeakPointer` outside a
`ThreadTransferable` struct. Call it on your own payload and state types; the
library's synchronized owners conform, so they pass. An `IOContext` does not:
it belongs to the poll of the fiber that receives it, so a type that keeps one
is rejected, and should not keep it.

Both checks are heuristics, not proofs. They trust standard-library types,
enter their elements only through iteration (`List`, `Optional`), and cannot
see `Dict` values, the payloads of `Variant`, `Tuple` and `OwnedPointer`, or
what a closure captures. A standard view such as `Span` passes, so it must
still not borrow state that the program can outlive. Synchronous `IO[E]`
programs keep their types and are not erased, so the check does not apply to
them; `unsafe_start` keeps its documented obligations.

## Provider matrix

Every operation that Cats Effect's `Sync` and `Async` type classes define, with
its provider for `IO[T, E]` (through `Async[E]`) and for the synchronous family
(through `SyncIO[E]`), or the obligation that stands in for one. Operations they
inherit from `MonadCancel`, `GenSpawn`, `GenConcurrent`, and `GenTemporal` are in
the [capability table](#write-programs-generic-over-the-family). Every row holds
on both qualified platforms, Linux x86-64 and macOS arm64.

| Cats Effect operation | `IO[T, E]`, `Async[E]` | `SyncIO[E]` | Obligation or contract | Current thread and pool |
|---|---|---|---|---|
| `Sync.delay`, `Defer.defer` | `IO.delay`, `IO.defer`; `delay[I]`, `defer[I]` | `delay[I]`, `defer[I]` | Callbacks own their state | Same on both; a callback may run on any worker of the pool |
| `Sync.blocking` | `IO.blocking`, `blocking[I]` on the root's `BlockingPool` | `blocking[I]`, inline | Uncancelable, as in Cats Effect | Current thread: the root's `BlockingPool`. Pool: on the calling thread, its worker's queue handed to a replacement, then the `BlockingPool` beyond `max_blocking_threads`. A configured `blocking_pool` on both |
| `Sync.interruptible`, `interruptibleMany` | `IO.interruptible`, `interruptible[I]` | `interruptible[I]`, inline | One operation: the request stays visible through the borrowed `Interruption`; no thread signal | Routed as `blocking`; the handle's waits wake on cancellation on both |
| `Sync.suspend(hint)`, `Sync.Type` | None | None | Excluded: each hint is its own operation above | — |
| `Clock.monotonic` | `IO.monotonic`, `monotonic[I]` | `monotonic[I]` | An `Instant` in the root's clock | Same on both: one clock per root |
| `Clock.realTime`, `realTimeInstant` | `IO.real_time`, `real_time[I]` | `real_time[I]` | One `SystemTime`; `TestControl` starts at the epoch | Same on both |
| `Unique.unique` | None | None | Excluded: fiber identity stays private | — |
| `Async.async`, `async_` | `IO.async`, `IO.async_` | None | The synchronous family cannot suspend; `complete` from any thread | `complete` from any thread on both; on the pool the continuation runs on any worker |
| `Async.asyncCheckAttempt` | None | None | Excluded: a registration may complete its `Completion` before returning, and `IO.async` observes it on its next poll without a wake | — |
| `Async.cont` | None | None | Excluded: Cats Effect's internal primitive behind `async` | — |
| `Async.never` | `IO.never`, `never[I, A]` | None | `Spawn` | Same on both |
| `Async.evalOn`, `startOn` | `io.eval_on(target)`, `io.start_on(target)`; `eval_on[I]`, `start_on[I]` | None | The target is an `ExecutionContext`: a `Runtime` or a `BlockingPool`. The program runs as its own root there and the caller resumes on its own root; children are drained at the region's end; `Fiber`, `Supervisor` and `Poll` may not cross ([execution contexts](#run-work-on-another-execution-context)) | Either profile as caller and as target; a current-thread runtime or a pool runs the region on one blocking thread |
| `GenSpawn.background`, `Async.backgroundOn` | `io.background()`, `io.background_on(target)`; `background[I]`, `background_on[I]` | None | A `Resource[Background[T, E], E]`: the use starts the fiber, release cancels it and waits; `Background.join` takes the outcome once ([background fibers](#background-fibers)) | Same on both |
| `Async.executionContext` | `IO.execution_context()`, `execution_context[I]` | None | `Optional[ExecutionContext]`: the region's target, or the runtime of `runtime.run`; None under the free `run`, `Driver` and `TestControl` | Same on both |
| `Async.fromFuture`, `fromFutureCancelable`, `fromCompletableFuture` | None | None | Not applicable: a foreign result completes an `IO.async` `Completion` | — |
| Runtime parking (`IORuntime`'s polling system) | `run` parks in the root's poller | `sleep_io` and `Interruption`'s waits park on a poller bridged from the cancellation token | No idle loop: an idle root uses no CPU and waits for its next deadline, an external wake, or a ready descriptor; timers fire within about 1 ms of their deadlines; a program nothing can wake waits forever | Current thread: the root's thread parks in its poller. Pool: each idle worker parks in its own; about 0.3 ms more CPU per idle 2 s |
| Embedding host loops | `Driver.park(timeout)`, or a notifier given to `Driver` | Not applicable | `park` waits for a deadline, a foreign wake, a ready descriptor, or the timeout; a return may be spurious; it raises `OSError`; `TestControl` has no `park` | Current thread only: `Driver` ignores the profile |
| `FileDescriptorPoller.awaitRead`, `awaitWrite` | `await_readable[E]`, `await_writable[E]` | `Interruption.await_readable`, `await_writable` inside `interruptible[I]` | On a `RawFileDescriptor` the caller owns and keeps open and nonblocking; readiness once per wait, hang-up and errors included | Current thread: the root's poller. Pool: the running worker's poller; a wait canceled from another thread is released by that worker |

### Profiles compared

What each part of the runtime promises on the current-thread profile and on
the work-stealing pool. Outcomes, laws, ownership and error order are the same
on both; the rows below are where the profiles differ or where the promise
needs stating.

| Area | Current thread | Work-stealing pool |
|---|---|---|
| A fiber's own steps | In order, one at a time | In order, one at a time, even when the fiber moves between workers |
| `Queue` values | FIFO | FIFO |
| `Deferred` readers | Every waiting reader receives the value | The same |
| Ready fibers, and which waiter a `Queue`, `Semaphore` or `Ref` serves first | Unspecified by the contract, though deterministic in practice | Unspecified, and varies between runs |
| A race whose sides finish together | The left side wins, deterministically | The first completion observed wins; either side may win |
| Determinism | One input gives one schedule, so a run repeats exactly | The order comes from the operating system's threads; covered by stress and soaks, not replay |
| `TestControl` and `Driver` | Always this profile, whatever the configuration says | Not available: they ignore the profile |
| `IO.blocking`, `IO.interruptible` | On the root's `BlockingPool`, a private one created on the first call unless `IORuntimeConfig.blocking_pool` is set | On the thread that made the call, with the worker's queue handed to a replacement, up to `max_blocking_threads` at once, then on the root's `BlockingPool`; a configured `blocking_pool` is used instead, never the hand-off |
| `blocking[SyncIO[E]]` | Inline on the calling thread | The same |
| Descriptor waits | Registered with the root's poller | Registered with the running worker's poller; a wait canceled from another thread is released by that worker |
| Timers | One heap per root | One heap per worker; searching workers steal expired timers |
| Idle parking | The root's thread parks in its poller | Each idle worker parks in its own poller |
| `Completion.complete` and other foreign wakes | From any thread; the continuation runs on the root's thread | From any thread; the continuation runs on any worker |
| Payload check | Every erased payload is checked at compile time | The same check: one contract on both profiles |
| Callbacks under a coordination lock (`Ref.modify`) | Never contended | A contended lock polls (see [known limits](#known-limits)) |
| `runtime.run` from inside a program | A current-thread runtime has no threads of its own | On one of the runtime's workers it aborts with a message; use `start` and `join` |
| `Runtime.fibers()`, `Driver.fibers()` | Both; a snapshot between polls | `Runtime.fibers()`; each fiber as it stood at some moment during the call |

## Run programs on a runtime

A `Runtime` owns the threads that run programs, as Cats Effect's `IORuntime`
does, but it is an explicit value: there is no global runtime. Its
`IORuntimeConfig.profile` decides where fibers run.

- **`Profile.work_stealing(workers)`**, the default with one worker per
  logical processor (on a host with a single logical processor the default
  is the current-thread profile, since a one-worker pool would only add its
  costs), runs fibers in parallel on `workers` threads that steal
  each other's queued work, after Cats Effect's work-stealing pool.
  `Profile.work_stealing()` uses one worker per logical processor, read when
  it is called. A count outside 1 to 32768 raises `Error`. Fibers share
  mutable state only as
  [share state across threads](#share-state-across-threads) describes.
- **`Profile.current_thread()`** runs every fiber of a root on the thread
  that runs the root, in a deterministic FIFO order. A current-thread
  `Runtime` starts no thread: each `run` runs its program on the calling
  thread. It is one setting away, for code that shares unsynchronized state
  between fibers or needs the deterministic order:

  ```text
  var config = IORuntimeConfig()
  config.profile = Profile.current_thread()
  var outcome = run(program^, config)
  ```

Both profiles keep the same outcomes, laws and ownership guarantees, and the
orderings listed under [drive external work](#drive-external-work-and-shutdown):
a fiber's steps stay ordered, queues stay FIFO, and every `Deferred` reader
receives the value. Only a race's tie changes: the current-thread profile
reports the left side, and the work-stealing profile reports the first
completion it observes.

`Runtime(config)` starts the workers its profile asks for and raises
`OSError` if a thread cannot start. `runtime.run(program)` and
`runtime.run(program, token)` return the program's `Outcome`, as the free
`run` does, using the runtime's configuration. On the work-stealing profile
the program runs on the workers while the calling thread waits for it: it
spins, then yields, for up to 50 µs, and then parks until the program
completes. Any number of threads may call `run` on one runtime at once.
Calling it on one of the runtime's own workers, from inside a program it
runs, aborts with a message, since it would block a worker the program may
need: inside a program, use `start` and `join`. Another runtime's worker, or
a blocking call, may call it, and blocks while it waits.

The free `run(program, config)` follows `config.profile` too. With the
work-stealing profile it makes a pool for the call, runs the program on the
calling thread as the first worker, and starts the other workers only when
there is work to steal, so a program that starts no fiber starts no thread.
A long-running application creates one `Runtime` and runs many programs on it
instead. A `runtime.run` costs more than the free `run`, because the
program goes to another thread and back: about 30 µs for `run(IO.pure(x))`
on an idle 4-core host, against about 4 µs for the free `run`, most of it
waking a parked worker. Under heavy host load it takes milliseconds, as the
operating system schedules the workers. Run many short steps inside one
program, with `start` and `join`, rather than many short `runtime.run`
calls. `Driver` and `TestControl` ignore the profile and always use the
current-thread profile.

**Shutdown.** Copies of a `Runtime` share it, as copies of a `BlockingPool`
share one pool, and there is no `close()`. When the last copy is dropped,
the runtime cancels the fibers still running, waits for them to finish, and
joins its threads. Each `run` holds a copy until it returns, so in practice
the last copy goes once every program has completed, and the shutdown only
joins idle workers. A last copy dropped on one of the runtime's own workers,
for example by a program that held one, cannot join that thread: the worker
finishes its current work and exits on its own, releasing the runtime last.

**Fiber dumps.** `runtime.fibers()` lists the live fibers of every program
running on the runtime, with `Driver.fibers()`'s contract: no payloads and no
completed fibers. `FiberInfo.root` numbers each program on its runtime, from
1 in submission order, and `index` and `owner` name slots of that program's
fiber table (`root` is 0 under a `Driver`). It may be called from any thread
at any time; while fibers run in parallel, each is listed as it stood at some
moment during the call.

`IORuntimeConfig` also holds `max_blocking_threads`, 64 by default, and
`blocking_idle_timeout`, 60 seconds: the work-stealing profile's bound on
threads blocked at once by blocking calls, beyond which calls queue on the
root's `BlockingPool`, and how long an idle one waits for reuse. They apply
to the whole pool, and only when `blocking_pool` is None: a pool given in
`blocking_pool` runs blocking calls on both profiles.

<!-- example: docs/examples/async_runtime.mojo -->

## Run work on another execution context

`io.eval_on(target)` runs `io` on another execution context and then resumes
the caller where it was, as Cats Effect's `evalOn` does. The target is an
`ExecutionContext`, which converts from a `Runtime` or a `BlockingPool`:

```text
var compute = Runtime()                     # a work-stealing runtime
var files = BlockingPool(max_workers=4)
var sum = parse(text^).eval_on(compute)     # runs on compute's workers
var data = read_all(path^).eval_on(files)   # runs on one of files' threads
```

**How a region runs.** `io` runs as its own root on the target, and the
caller waits for it as for an `IO.async` registration: a fiber never moves
between schedulers. Nested regions return to each caller's context.

- On a **work-stealing runtime**, the region is one of the runtime's programs,
  on its workers, and `runtime.fibers()` lists its fibers while it runs.
- On a **current-thread runtime**, which starts no thread of its own, the
  region runs on one thread of the runtime's blocking pool, its
  `IORuntimeConfig.blocking_pool` or a private pool, for the region's whole
  length; its fibers run on that one thread, in the current-thread order.
- On a **`BlockingPool`**, the region runs the same way on one of the pool's
  threads, with the caller's interpreter settings. Its own blocking calls use
  a private pool, so they never wait behind the region on its target.

**Outcomes and cancellation.** Success, failure and cancellation pass through
unchanged. Canceling the caller while the region runs cancels the region and
waits for it to finish, so `io`'s finalizers run on the target exactly once
before the cancellation completes. Under `uncancelable` the region runs to
its end; a region restored with the mask's `Poll` is canceled. If `io`
cancels itself, the caller is canceled too.

**Ownership.** Children that `io` starts belong to the region and are
canceled and drained when it ends, not when the caller's fiber ends: this is
the one difference from Cats Effect, where `evalOn` keeps the same fiber.
`Fiber`, `Supervisor` and `Poll` values are tied to the root that made them,
so `eval_on` rejects them at compile time in the region's value or error,
including inside `List`, `Optional` and struct fields. The check cannot see
values captured inside `io`'s callables, or inside `Tuple`, `Variant`, `Dict`
values, `OwnedPointer` payloads and `Ref`, `Deferred` or `Queue` cells: using
a caller's `Fiber` or `Supervisor` from inside a region is unsupported, and a
caller's `Poll` has no effect there.

**Lifetime.** The region holds a copy of its target until it has finished, so
a target whose other owners are all gone keeps running the region and then
shuts down, from the region's own thread. `io`, its value and its error move
to the target's threads and back, under the
[thread-safety contract](#share-state-across-threads).

**`start_on`** is `io.eval_on(target).start()`: an ordinary child of the
caller whose work runs on the target. **`execution_context()`** returns the
running program's context: the target inside a region, the runtime inside
`runtime.run`, and None under the free `run`, `Driver` and `TestControl`,
which have no `Runtime` value. Two contexts are equal when they refer to the
same runtime or pool. The `EvalOn` capability and `LiftEvalOn` give generic
code the same operations.

### Background fibers

`io.background()` is Cats Effect's `background`: a `Resource` whose use runs
`io` as a fiber beside the body, and whose release cancels the fiber and
waits for it. `io.background_on(target)` is `io.eval_on(target).background()`.

```text
var summed = ticker^.background().use(watch)   # watch borrows a Background[T, E]
```

The shape differs from Cats Effect's `Resource[F, F[Outcome]]`. A `Resource`
lends its value to the body by borrow, and an `IO` is move-only and runs once,
so a borrowed join could never run. The value is instead a
`Background[T, E]` handle: `join()` builds an IO that waits for the fiber and
takes its outcome, and `cancel()` cancels it and waits, as on a `Fiber`. The
outcome is taken once, as from a `Fiber`: a second join that runs aborts,
naming the call. A failure no join took is reported when the resource is
released, as for a dropped `Fiber` handle. `background` is a member of
`Spawn`, and `background_on` of `EvalOn`, so generic code and `OptionalT` and
`ResultT` layers have them too; a layer gets the base's resource, whose
handle joins the layer's wrapped value.

**Cost.** A region is one root submission and one foreign wake: about the
cost of a `runtime.run`, tens of microseconds, against nanoseconds for a
bind. On a current-thread runtime or a `BlockingPool` the region also holds
one blocking thread while it waits. Use regions for coarse work, such as a
CPU-bound computation on a dedicated runtime or a blocking subsystem on its
own pool.

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

`IO.async(register, withdrawal)` runs withdrawal after every entered
registration, including successful completion and registration failure, so
withdrawal is where a registration releases what it registered. This differs
from Cats Effect, whose `async` finalizer runs only when the waiting fiber is
canceled. `IO.async_` has no withdrawal. Copies of `Completion` share one
decision. `complete` may be called from any thread, and writes made before it
are visible to the continuation that receives the value. Late or duplicate
payloads are rejected and destroyed on the completing thread, so their
destructors must not need the polling thread. `timeout_to` requests cancellation and drains the source before
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

`TestControl[P]` runs a program on virtual time, as Cats Effect's
`TestControl` does: it owns a `Driver` on a manual clock that starts at zero.
`tick` runs everything runnable without moving time, `tick_one` takes one root
poll, `advance` and `advance_and_tick` move time, `next_interval` reports the
time to the next deadline, `tick_for` runs through every deadline within a
duration, and `tick_all` alternates ticking and advancing until the program
completes or nothing is scheduled. `is_deadlocked` reports an incomplete
program with nothing runnable, no deadline, and no `IO.async` registration
awaiting completion. Like Cats Effect, it assumes nothing else delivers
events: a program waiting on a `Deferred` that the test could still complete
also reports a deadlock. `results` takes the outcome once the program
completes; to stop one that cannot, `request_cancel` and tick again.

<!-- example: docs/examples/async_test_control.mojo -->

Events delivered between ticks, by completing an `IO.async` registration or a
shared `Deferred`, `Queue`, or `Ref`, are observed at the next tick.

An `eval_on` region started under `TestControl` or a `Driver` runs on its
target in real time, and its end arrives as a foreign wake, like an
`IO.async` completion. While it runs, `TestControl` reports the program as
neither completed nor deadlocked, since the region's registration is live, and
`next_interval` reports no deadline for it; `tick` returns with nothing
runnable, so a test ticks again until the region's result arrives. A seed
does not choose when that happens, so a replayed trace that includes a
region is exact only up to the region's end.

**The orderings the runtime promises**, on both profiles:

- a fiber's own steps run in order, one at a time, even when the fiber moves
  between workers;
- queued values leave a `Queue` in FIFO order;
- every waiting `Deferred` reader receives the value.

Races differ by profile. On the current-thread profile, and so under
`TestControl` and `Driver`, a race whose sides finish in the same tick
reports the left side, deterministically. On the work-stealing profile both
sides may finish at the same moment on different workers, and the first
completion observed wins: either side may win a tie, and the loser is
canceled and drained as before. The order in which several ready fibers run,
and which waiter a `Queue`, `Semaphore`, or `Ref` serves first, are
unspecified on both profiles.

**Exploring the unspecified orders.** By default `TestControl` runs the
fibers that are ready together in FIFO order, so a test that passes once
passes every time, possibly only because of that order. Constructed with a
seed, `TestControl(program, seed=s)` or `TestControl(program, config,
seed=s)`, it explores instead: whenever several fibers are ready together, the
seed chooses which runs first. Run a check over a range of seeds to cover the
orders the contract allows, as Loom and CHESS explore schedules.

- **What it varies.** The order of the fibers ready together, and through
  it which waiter a `Queue`, `Semaphore` or `Ref` serves first, the order in
  which timers due at the same instant and the subscribers of one signal
  resume, and so where cancellation lands relative to another fiber's steps.
- **What it keeps.** The promised orderings above: a fiber's own steps,
  FIFO `Queue` values, every `Deferred` reader receiving the value, and the
  left side of a race whose sides finish together. A tick is a series of
  phases: each takes the fibers that today's FIFO turn would run next, and a
  fiber woken during a phase runs in a later one, so a race whose sides
  finish in the same phase sees both finished and reports the left side.
  Choosing the first candidate every time is the default FIFO order.
- **What it does not vary.** Virtual time, external events, which the test
  delivers itself, and the work-stealing pool, whose order comes from its
  threads: stress tests and soaks cover the pool. A ready fiber is never held
  back to a later tick, and the transition budget's yield points stay fixed.

`trace()` returns the run's `ScheduleTrace`: its `seed()` and its
`choices()`, one index for each phase with more than one candidate. It
prints as `seed=7 choices=2/3,0/2`, each choice written over its candidate
count. Print it when a check fails; `ScheduleTrace.parse` reads it back, and
`TestControl(program, replay=trace)` repeats the run exactly. A replay makes
the recorded choices and then continues as its seed would, so a seed alone
replays its run too. A program that no longer offers the recorded candidates
aborts, naming the first choice that diverged. A deterministic control's
`trace()` is `None`.

```text
for seed in range(1000):
    var control = TestControl(program(), seed=UInt64(seed))
    control.tick_all()
    var trace = control.trace().value().copy()
    if not promised(control^.results()):
        abort(String("failed; replay with ", trace))
```

`run` blocks until self-contained work drains. While nothing is runnable it
parks the thread in the root's poller until the next deadline, an external
wake from any thread, or a ready descriptor, so an idle program uses no CPU and
timers fire close to their deadlines; a program that nothing can wake waits
forever, as in Cats Effect. Use `Driver` when the host must deliver events or
advance manual time. A pending driver with no runnable work may require an
external signal or its reported deadline.

A host that drives a `Driver` from its own loop can park the same way:
`park(timeout)` returns at once when the program is completed or runnable, and
otherwise waits until the earliest deadline, an external wake, a ready
descriptor, or the optional timeout, whichever comes first. A return may be
spurious, so poll next and park again while nothing is runnable. The deadline
is measured on the driver's clock: a manual clock does not move while parked,
and `TestControl` has no `park`. The poller's self-pipe opens on the first park
or descriptor wait, so a driver that never parks opens none. `park` raises
`OSError` when the pipe cannot be opened or `poll` fails, and leaves the driver
usable; `run` aborts with the message instead.

```text
var progress = driver.poll()
while not progress.completed:
    if not progress.runnable:
        driver.park(host_timeout)
    progress = driver.poll()
```

`OSError` names the failed call and its `errno`; `is_again()` reports
`EAGAIN`, and it writes as `<call> failed: errno <number>`.

A host with its own event loop can pass a notifier, any repeatable
non-raising `Thunk`, as the last argument of
`Driver(program, token, clock, config, notifier)`: the driver calls it, possibly
from the thread that delivered the event, when an event arriving while no poll
runs makes the program runnable. The notifier must return promptly, must not
call back into the driver, and must be safe on that thread; it is never called
after `finish` returns, and `finish` waits for a call in progress.

### Wait for file descriptors

Library authors build pipes, sockets, or process I/O on two low-level waits in
`fp.effects.async_runtime.protocols`, after Cats Effect's
`FileDescriptorPoller`. `await_readable[E](fd)` and `await_writable[E](fd)`
take a `RawFileDescriptor` and return an `IO[NoneType, E]` that suspends the
fiber in the root's poller until the descriptor is ready. Hang-up, error and
invalid-descriptor conditions count as ready, and the next read or write
reports them. Readiness is reported once per IO, so wait again before each
retry:

```text
var program = await_readable[E](RawFileDescriptor(fd)).flat_map(ReadChunk(fd))
```

The caller owns the descriptor and keeps it open and nonblocking until the IO
completes; Mojo closes an owned descriptor after its last use, so keep its
owner alive past the wait. Cancellation completes the wait canceled and
removes its registration, and a masked wait waits for readiness. The wait
never fails with `E`. A negative descriptor, a wait outside a `Driver`, `run`
or `TestControl`, or a failure to open the root's poller aborts. `Driver.poll`
checks watched descriptors without waiting, so a host that never parks, and a
test under `TestControl`, see readiness at the next poll or tick.

<!-- example: docs/examples/async_descriptors.mojo -->

## Responsiveness

How quickly the runtime reacts, measured on both profiles at O3 on the 4-core
Linux x86-64 development host, with the pool at four workers, at commit
`335a667`. The 1-minute load average was 1.0 to 1.4, from these measurements
alone. Three values in a cell are the median, 90th percentile and maximum of
200 samples. `experiments/async-state-machines/probes/responsiveness.mojo`
measures cancellation and the one-way wake on the build's default profile, so
it was built twice, with `-D FP_ASYNC_PROFILE=current_thread` and
`=work_stealing`. Timer lateness (200 sleeps), idle CPU (the median of five
runs) and the round trip are the `sleep`, `idle` and `rtt` cases of
`probes/profile_compare.mojo`.

| Measurement | Current thread | Work-stealing pool |
|---|---|---|
| Cancel a busy fiber: its steps after the request (two transitions each) | 0, 0, 0 | 40, 52, 113 |
| Cancel a busy fiber: wall time of `fiber.cancel()` | 4.7, 5.7, 23 µs | 6.7, 8.4, 26 µs |
| Cancel a parked fiber: wall time of `fiber.cancel()` | 5.3, 5.7, 11 µs | 7.1, 11, 295 µs |
| One-way foreign wake of a parked program | 122, 171, 280 µs | 132, 195, 379 µs |
| Foreign completion round trip, completer spinning | 7.6 µs | 7.9 µs |
| 1 ms sleep lateness, median and 90th percentile | 101, 170 µs | 120, 201 µs |
| Process CPU of an idle 2 s `run` | 0.21 ms | 0.54 ms |

- **Cancellation in transitions.** On the current thread the canceler runs
  only between the busy fiber's slices, so the fiber observes the request at
  its next checkpoint: no step runs after it. A fiber that never yields
  delays its owner by up to one slice, `auto_yield_threshold` transitions
  (1,024 by default). On the pool the canceler and the fiber run at once, and
  the fiber takes 40 steps, about 80 transitions, to see the request; with
  `cancelation_check_threshold = 1` it checks at every bind.
- **Wakes from other threads** go through the poller's self-pipe. On this
  virtual machine, returning from `poll()` costs about 0.1 ms, the same on
  both profiles, which is also what a timer is late by. When the program has
  not parked yet, the round trip is about 8 µs.
- **Idle.** Neither profile spins. The pool uses about 0.3 ms more CPU per
  idle 2 s, as the scheduler's
  [profile comparison](../architecture/async-scheduler.md#profiles-compared)
  also measured.

These are local diagnostics, not service-level objectives. Shared host load
moves the tails.

## Known limits

- **Two qualified platforms.** Linux x86-64 and macOS arm64 are qualified. OS
  threads compile only on 64-bit Linux and macOS; Linux ARM64 builds, but its
  threaded runtime has not been qualified. Pool and blocking threads get glibc's
  default stack on Linux and 8 MiB on macOS, whose own default for secondary
  threads is 512 KiB.
- **Thread safety verification.** The pool's correctness rests on the
  [ordering audit](../architecture/async-thread-safety.md#memory-ordering-audit),
  comprehensive multi-threaded stress clients, and soak tests.
- **Held coordination locks poll.** A fiber that finds a `Ref`, `Deferred`,
  `Queue` or `Semaphore` locked by a fiber on another worker is rescheduled
  at once and tries again, so waiting workers busy-poll. Under heavy
  contention the pool burns CPU for serialized work: 16 fibers on one `Ref`
  used about 3.9 cores for 1 core of work. Keep callbacks under a lock short.
  A wait queue that wakes one waiter cut that CPU about fourfold but lowered
  throughput at every callback length, so it was not adopted
  ([held coordination locks](../architecture/async-scheduler.md#held-coordination-locks)).
- **Fire-and-forget is not provided.** Every `run` holds a copy of its
  `Runtime`, so the last copy is dropped only after every program completed.
  `eval_on` regions, the one kind of program nobody waits for, each hold a
  copy until they finish, and give it up only after leaving the runtime's
  registry, so the last copy never finds a live program. A future public call
  that starts a program without waiting for it must keep that rule.
- **Execution contexts are separate roots.** A region's children are drained
  when the region ends, and a caller's `Fiber`, `Supervisor` or `Poll`
  captured inside a region is not detected at compile time
  ([execution contexts](#run-work-on-another-execution-context)).
- **`Parallel` through transformer layers covers `OptionalT` and `ResultT`
  only.** `ReaderT`, `StateT` and `WriterT` are rejected at compile time,
  although Cats provides `Parallel` for `Kleisli` and `WriterT`. Through
  `OptionalT` and `ResultT`, an absent value or a stored error does not stop
  the other elements, unlike the sequential `traverse`.
- **Fibers that cede to each other cost about twice as much on the pool**
  as on the current thread: a pair that cedes to each other takes about
  36 µs against 18 µs. A ceding fiber goes back to its worker's queue, where
  a second entry wakes another worker. The runtime notifies immediately to preserve
  fair scheduling and low wake latency
  ([ceding pairs](../architecture/async-scheduler.md#ceding-pairs-and-notification-policy)).
  Fibers that hand work to each other without ceding, and joins, cost the
  same on both profiles. For code dominated by ceding hand-offs, use
  `Profile.current_thread()`, or hand off through a `Deferred` or `Queue`.
- **Replay is current-thread only.** The work-stealing pool's order comes from
  real threads; stress and soaks cover it instead.
- **Allocation pooling is not adopted**; see the
  [comparison with the foundation](../architecture/async-qualification.md#comparison-with-the-foundation).

## Cats and Cats Effect mapping

| Scala concept | Mojo spelling | Contract |
|---|---|---|
| `IO[A]` | `IO[T, E]` | Exact domain error; one value runs once |
| `IO.pure`, `IO.delay`, `IO.defer`, `IO.raiseError` | `IO[T, E].pure`, `.delay`, `.defer`, `.raise_error` | `defer` builds recursive programs lazily |
| `flatMap`, `map`, `tailRecM` | `flat_map`, `map`, `tail_rec_m[Async[E]]` | Constant native stack |
| `attempt`, `handleErrorWith` | `attempt`, `handle_error_with` | Complete failures; mixed cancellation bypasses recovery |
| `guarantee`, `guaranteeCase`, `onCancel`, `uncancelable` | `guarantee`, `guarantee_case`, `on_cancel`, `IO.uncancelable` | Masked cleanup with the exact exit |
| `IO.async`, `IO.async_` | `IO.async`, `IO.async_` | Withdrawal runs after every entered registration, not only on cancellation; `complete` from any thread |
| `IO.cede`, `IO.never`, `IO.sleep`, `IO.canceled` | the same, on `IO[T, E]` | |
| `FileDescriptorPoller` readiness | `await_readable[E](fd)`, `await_writable[E](fd)` in `async_runtime.protocols` | Once per IO; hang-up and errors count as ready; the caller owns the descriptor |
| `IO.blocking` | `IO[T, E].blocking(f)`, `blocking[I](f)` | Uncancelable; runs on the root's `BlockingPool`; inline in `SyncIO[E]` |
| `IO.interruptible`, `IO.interruptibleMany` | `IO[T, E].interruptible(f)`, `interruptible[I](f)` | The function borrows an `Interruption`; a request stays visible; no signal; cancellation completes when it returns |
| Blocking execution context | `BlockingPool`, `IORuntimeConfig.blocking_pool` | Per root unless shared; no process-wide pool; bounded by `max_workers` |
| `IO.evalOn`, `startOn`, `executionContext`, `Async.evalOn` | `io.eval_on(target)`, `io.start_on(target)`, `IO.execution_context()`; `EvalOn` with `eval_on[I]`, `start_on[I]`, `execution_context[I]` | The target is an `ExecutionContext` (a `Runtime` or `BlockingPool`); the region is its own root, so its children are drained at its end |
| `IO.monotonic`, `timed`, `timeout`, `delayBy`, `andWait` | `IO[T, E].monotonic()`, `timed`, `timeout`, `delay_by`, `and_wait` | Monotonic `Instant` |
| `IO.realTime`, `realTimeInstant` | `IO[T, E].real_time()`, `real_time[I]()` | Wall-clock `SystemTime`, never an `Instant`; `since` reports a backward step |
| `both`, `race`, `timeoutTo` | `both`, `race`, `timeout_to` | Cancel and drain; surviving source outcomes can win |
| `IO.Par`, `Parallel[IO]` | `AsyncPar[E]`, `Async[E].Par`; the `Parallel` trait | Same carriers, so no natural transformations; not a `Monad` |
| `parTraverse`, `parSequence`, `parTraverse_`, `parMapN`, `parTupled` | `par_traverse`, `par_sequence`, `par_traverse_void` (in `fp.iteration`), fluent `par_map_n`, `par_product_n` | Callbacks in source order; the first unsuccessful element stops the rest; every observed error, in element order |
| `parTraverseN`, `parSequenceN`, `parTraverseN_` | `par_traverse_n`, `par_sequence_n`, `par_traverse_void_n` | A live limit, not a semaphore; a limit below one aborts at the call |
| Earlier selection policies | `race_first`, `timeout_after` | First terminal outcome, or timer-selected fallback after clean draining |
| `Resource.make`, `makeCase`, `use` | `Resource.make`, `make_case`, `use`, `use_scoped` | Scoped borrowing; reverse release order |
| `MonadCancel`, `GenSpawn`, `Sync` | `Cancel`, `Spawn`, `Defer`, `Raise`, `Blocking` dictionaries: `Async[E]`, `SyncIO[E]` | Narrower capabilities stay narrower; the synchronous family has no `Spawn` |
| `MonadCancel[OptionT[F, *], E]` and the other transformer instances | `LiftDefer`, `LiftRaise`, `LiftTiming`, `LiftBlocking`, `LiftCancel`, `LiftSpawn`, `LiftConcurrent`, `LiftTemporal` selections | Cancel, Spawn, Concurrent, and Temporal forward through `OptionalT` and `ResultT` only; case finalizers observe the base exit |
| `Ref.of`, `Deferred[F, A]`, `GenConcurrent` | `Ref(value)`, `Deferred[T]()`, `Concurrent` with `make_ref[I]`, `make_deferred[I, T]` | Updates cannot raise; reads copy, so `get` needs copyable state |
| `Clock`, `GenTemporal` | `Timing` and `Temporal` dictionaries | `SyncIO[E]` provides `Timing` only |
| `fa.start`, `fiber.join`, `fiber.cancel` | `io.start()`, `fiber^.join()`, `fiber.cancel()`, `fiber.request_cancel()` | Owners drain unjoined children before completing |
| `fa.background`, `fa.backgroundOn(ec)` | `io.background()`, `io.background_on(target)` | A `Resource[Background[T, E], E]` instead of `Resource[F, F[Outcome]]`: `use` borrows its value and an `IO` runs once, so the body gets a handle whose `join` takes the outcome once |
| `Supervisor(await).use(f)`, `supervise` | `Supervisor[E].scoped(f, await_on_release)`, `supervisor.supervise(io)` | Release cancels live supervised fibers unless it awaits them |
| `racePair` | `io.race_pair(other)` | A `RaceWinner` with the first outcome and the other fiber |
| `joinWith`, `joinWithNever`, `joinWithUnit` | `join_with`, `join_with_never`, `join_with_unit` | A canceled child runs the fallback, waits, or produces unit |
| `TestControl.execute`, `tick`, `tickOne`, `tickFor`, `tickAll`, `advance`, `advanceAndTick`, `nextInterval`, `isDeadlocked`, `results` | `TestControl(program)`, `tick`, `tick_one`, `tick_for`, `tick_all`, `advance`, `advance_and_tick`, `next_interval`, `is_deadlocked`, `results` | A linear owner: `results` consumes a completed program |
| No counterpart (Loom and CHESS explore schedules) | `TestControl(program, seed=s)`, `TestControl(program, replay=trace)`, `trace`, `ScheduleTrace` | Seeded exploration of the fibers ready together; the promised orderings stay fixed; current-thread profile only |
| `IORuntime`, `IORuntime.global`, `unsafeRunSync` | `Runtime(config)`, `runtime.run(program)`; the free `run` | An explicit value, no global: copies share it and the last copy cancels, drains and joins; `run` on one of its own workers aborts; no `unsafeRunAndForget` or `unsafeToFuture` |
| `WorkStealingThreadPool`, a single-threaded runtime | `Profile.work_stealing(workers)`, `Profile.current_thread()` in `IORuntimeConfig.profile` | The work-stealing pool by default, one worker per logical processor, and the current thread on a one-processor host; `Driver` and `TestControl` always use the current thread |
| `IORuntimeConfig` | `IORuntimeConfig(cancelation_check_threshold, auto_yield_threshold)` | Same validation; by default checks every bind, where Cats Effect checks every 512, and yields every 1,024 transitions |
| `reportUnhandledFiberErrors`, `reportFailure` | `IORuntimeConfig.report_unhandled_fiber_errors`, `.reporter` | On by default; reports when the last handle or join is dropped |
| Fiber dump | `Driver.fibers()`, `Runtime.fibers()` returning `FiberInfo` | Live fibers with owner and status, no payloads; a runtime's dump numbers its programs in `root` and may be taken from any thread |

Operations use snake_case. Types follow the repository's Mojo class convention.
`async` is declared with backticks because it is a Mojo keyword, and called as
`IO[T, E].async(...)`. `Async[E]` supplies sequencing and error recovery; it is
not the full Cats Effect `Async[F]` hierarchy. Queue values are FIFO, with no
waiter fairness promise. Public type parameters and documented metadata are
supported; compiler type spellings, storage, ABI, allocation counts, and
compilation complexity are not stability promises.

### Migrating from recipes

Earlier previews exposed one typed recipe per operation; every operation now
returns `IO`. The [migration guide](async-migration.md#from-typed-recipes-to-io)
maps each recipe to its replacement.

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

Focused source/package checks at O0/O3 cover the runtime on Linux x86-64 and
macOS arm64. The completed
[overnight qualification](../architecture/async-qualification.md#overnight-results)
on Linux x86-64 adds twelve one-hour stress cases, retained-storage checks, and
separate local performance measurements.

For architectural details on execution state machines, fiber scheduling, and
thread safety contracts, see [explicit async state machines](../architecture/async-state-machines.md)
and [wake-driven execution](../architecture/async-scheduler.md).
