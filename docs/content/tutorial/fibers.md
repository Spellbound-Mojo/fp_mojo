# 13. Concurrency with fibers

A *fiber* is a lightweight, cooperatively scheduled unit of execution that runs an
`IO` computation concurrently alongside its parent task. The `fp.effects.async_runtime`
package guarantees **structured concurrency**: a child fiber can never outlive its
enclosing scope or parent task. When an owner finishes or fails, the runtime
automatically cancels any live child fibers, waiting for their finalizers to finish
cleanly before completing the parent.

By default on 64-bit Linux, `run` utilizes a high-throughput work-stealing pool where ready
fibers execute in parallel across OS worker threads. On single-core environments, on macOS,
or during deterministic testing, the current-thread executor processes fibers in turn
([chapter 14](running.md)). The examples in this chapter produce identical,
deterministic results across both execution profiles.

Because async tasks can be dispatched across worker threads, IO callbacks must strictly
own their state. Plain functions qualify directly; closures capturing local stack
references are rejected at compile time. Steps requiring parameters from earlier stages
(such as a child fiber handle) are expressed as lightweight structs implementing `OnceUnary`.

## Start a fiber, then join or cancel it

`io.start()` is an `IO[Fiber[T, E], E]`. Running it starts `io` as a child
fiber and produces a handle to it. The child has the same error type `E` as
its owner. `fiber^.join()` consumes the handle and waits until the child and
its cleanup have finished. It then produces the child's `Outcome[T, E]` as a
value. A failed child does not make the join fail: the owner receives the
failure and decides what to do with it.

<!-- example: docs/examples/async_fibers.mojo -->

The first program starts `IO[Int, Int].pure(6).map(times_seven)` and passes
the handle to `Join`. `Join` joins the child, and `TakeValue` takes the
success out of the child's outcome, so the program prints `joined: 42`.

`fiber.cancel()` borrows the handle. It requests cancellation and then waits
for the child to finish; the wait itself cannot be canceled.
`fiber.request_cancel()` only makes the request. In `cancel_running`, the
child completes the `Deferred` `started`, then waits in `IO.never()` under a
`guarantee` finalizer. `CancelOnceStarted` waits on `started` before
canceling. That wait matters: a child canceled before its first step runs
nothing, not even its finalizers. Here the child is already inside its
guarded region, so `child cleanup ran` prints. The join that follows produces
an absent outcome, the cancellation, and the program prints
`canceled: True`.

To join and continue with a plain value, use one of the other joins:

| Join | Child succeeded | Child failed | Child was canceled |
|---|---|---|---|
| `join()` | `Outcome` holding the value | `Outcome` holding the failure | Absent `Outcome` |
| `join_with(fallback)` | The value | Fails with the child's errors | Runs `fallback` |
| `join_with_never()` | The value | Fails with the child's errors | Waits until the joiner is canceled |
| `join_with_unit()`, for `T = NoneType` | `None` | Fails with the child's errors | `None` |

Dropping a handle neither stops the child nor detaches it. The child keeps
running until it ends or its owner's program finishes. A child that the owner
never joins does not change the owner's outcome. A fiber that joins its own
handle aborts.

## Report a failure that nobody joins

Each fiber failure is either joined or reported, exactly once. A failure is
reported when nothing can join it any more: when its handle is dropped, or,
if the child is still running then, when the child completes. An unjoined
success is destroyed. The reporter is `IORuntimeConfig.reporter`, a plain
function that receives one formatted line. By default it writes to standard
error, and `report_unhandled_fiber_errors = False` turns reporting off.

<!-- example: docs/examples/fibers_unjoined.mojo -->

The child fails with `"disk full"`. Its `guarantee` finalizer then completes
`failed`, so the owner knows that the failure has happened. `DropAfterFailure`
destroys the handle without joining it and waits on `failed`. When the owner's
program ends, the failure has no claim left, so `print_report` receives
`unhandled fiber failure: disk full`. The owner's own outcome is unchanged:
its value is the `1` read from `failed`, which prints as `owner: ok 1`.

The report always arrives before `run` returns, because the owner does not
complete until its children have. The reporter may be called from any thread
that settles a fiber, and from several threads at once on the work-stealing
profile, so it must be safe to call there. When `E` is `Writable`, the line
lists the errors, separated by `; `. Otherwise it gives their count and type.
A failure that recorded cancellation ends with ` (canceled)`.

## Run two programs at once with both

`a.both(b)` starts both programs as fibers and produces
`IO[Tuple[T, U], E]` once both have succeeded. In `async_fibers.mojo`, the
two sides produce `20` and `22`, and `add_pair` prints `both: 42`.

When one side ends unsuccessfully, `both` cancels the other side, waits for
it to finish, and fails. The failure lists the left side's errors before the
right side's. Canceling the other side does not mark the failure canceled, so
`handle_error_with` can recover it, as in Cats Effect. Both sides need the same error type `E`; their value types may
differ, and move-only values are supported.

## Take the first result with race

`a.race(b)` starts both sides as fibers and produces
`IO[RaceResult[T, U], E]` from the first side whose outcome is not
cancellation-only. `RaceResult` is a `Choice` of `Left[T]` and `Right[U]`, so
you can tell the sides apart even when `T` and `U` are the same type. The
losing side is canceled and drained before the race completes. A losing
success is destroyed. A losing failure is kept: the race then fails, and
the loser's errors follow any errors of the winner. A failure can also win:
`race` selects the first outcome, not the first success.

In the example, the left side sleeps for 1 ms and produces `1`. The right
side, `IO[Int, Int].never()`, never finishes. The left side must win, so
`left_won` returns `True` and the program prints `left won the race: True`.
The right side is canceled and drained.

The race is set up so that only one side can finish. When both sides finish
at nearly the same moment, the winner depends on the profile. The
current-thread profile reports the left side. On the work-stealing profile,
the sides may finish on different workers, and the first completion
observed wins. If one side ends canceled, `race` waits for the other side's
result. `race_first` instead selects the first terminal outcome, including a
cancellation. `race_pair` produces the first outcome together with the other
side's fiber, which you can join or cancel yourself.

## Bound a program with a timeout

`io.timeout_to(duration, fallback)` runs `io` as a fiber against a deadline.
The deadline starts when the timeout is entered. When the deadline passes,
the timeout requests cancellation of `io` and waits for it to finish. If `io`
still produced a success or a failure, that result is kept. The fallback runs
only when `io` ended canceled. `io.timeout(duration, error)` fails with
`error` in that case instead.

<!-- example: docs/examples/fibers_timeout.mojo -->

Each timeout in the example allows 20 ms. `IO[Int, String].pure(7)` finishes
at once, so the first timeout keeps `7` and the unopened fallback is
destroyed. `IO.never()` is still running at the deadline. It is canceled, and
then the fallback produces `-1`. The third program uses `timeout` with the
error `"lookup timed out"`, so its outcome is that failure.

The fallback must have the same value and error types as the source. It is
not opened while the source drains, and it is skipped if the source's cleanup
fails or the enclosing program is canceled. A deadline only requests
cancellation: it cannot stop masked work or cleanup, and the timeout waits
for them. `timeout_after(duration, fallback)` uses the deadline-first policy
instead. Once the deadline wins, it runs the fallback after draining, even
when masked work in the source went on to succeed.

## Process a collection concurrently

`par_traverse(source, f)`, from `fp.algebra`, runs the `IO` that `f` builds
for each element as a child fiber of the running fiber.
`par_sequence(programs)` does the same for a collection of `IO` values. The
`Async[E]` family is inferred from the callback's result.

<!-- example: docs/examples/async_par_traverse.mojo -->

`square_later` cedes once before producing its square, so the elements finish
in whatever order the scheduler runs them. The results still keep source
order: `squares: 1 4 9 16`. The callback itself runs on the running fiber, in
source order, when the program runs. `par_traverse_n(2, ...)` keeps at most
two elements running at once. A finished element frees its place for the
next one, and the program prints `bounded: 25 36 49`. `par_sequence` gives
`sequenced: 10 20`.

The first element that ends unsuccessfully stops the others. Every child that
started finishes, cleanup included, before the program completes. The
failure carries every error observed by then, in element order. Elements not
yet pulled from the source are never started. In the example, `reject_odd`
fails only for `3`, so the failure holds `3`. An empty source produces an
empty result and starts no fiber.

The last line shows the other `par_traverse`. With a callback that returns a
`Result`, it is error-accumulating validation: it starts no fibers and
collects the errors of both `-3` and `-5`.

## Keep fibers alive past a scope with a supervisor

A started fiber belongs to the fiber that started it.
`Supervisor[E].scoped(body)` lends `body` a `Supervisor`, and
`supervisor.supervise(io)` starts `io` as a fiber owned by the supervisor
instead. That fiber can outlive the fiber that called `supervise`. When the
body ends, a masked release cancels the supervised fibers that are still
running and waits for them. With `await_on_release=True`, it waits for them
to finish instead.

In `async_fibers.mojo`, `SuperviseAndJoin` supervises
`IO[Int, Int].pure(6).map(times_seven)` and joins the handle, so the program
prints `supervised: 42`. Copies of a supervisor share it, so any fiber that
holds a copy can supervise. Release closes the supervisor first. A
`supervise` that runs after release has begun returns a fiber that is already
canceled; its program never runs.

## Share state between fibers

Fibers share mutable state through the library's synchronized owners. Each
operation on them is an `IO` that runs when reached. Copies of a `Ref`,
`Deferred`, `Queue` or `Semaphore` share the same state.

<!-- example: docs/examples/async_coordination.mojo -->

- **`Ref(value)`** is a shared cell. An update runs once under the cell's
  guard and never suspends, so it is atomic with respect to other fibers. In
  `counted`, two fibers run `update(increment)` on one cell through `both`,
  and the read afterwards prints `counter: 2`. Updates cannot raise, because
  a failed update would lose the consumed state. `get`, `get_and_update` and
  `update_and_get` copy the state; `set`, `get_and_set`, `update`, `modify`
  and `inspect` also work for move-only state.
- **`Deferred[T]()`** is assigned once. `complete(value)` produces whether
  this assignment won. `get()` waits for the assignment, and each waiting
  reader receives its own copy, so `T` must be `Copyable`. In `awaited`, two
  readers each receive `42`, which prints `deferred readers: 84`.
- **`Queue[T](capacity)`** is a bounded FIFO. `offer` waits for room and
  `take` waits for a value; `try_offer` and `try_take` return at once. With
  a capacity of two, the producer in `queued` waits while the queue is full.
  The values still leave in order: `queue: 1 2 3 4`. Move-only values are
  supported.
- **`Semaphore(permits)`** hands out permits. `with_permit(program)`
  acquires a permit, where the wait can still be canceled, runs the program,
  and releases the permit on success, failure or cancellation. The example
  prints `with permit: 7`, and `available()` prints `permits after: 1`.

Values leave a `Queue` in FIFO order, and every waiting `Deferred` reader
receives the value. Which waiting fiber a `Queue`, `Semaphore` or `Ref`
serves first is unspecified. Callbacks given to these owners follow the IO
rule: plain functions or owned library callables. Keep callbacks that run
under a guard, such as `Ref.update`, short, and do not use the same owner
from inside them.

## Share only what may cross threads

On the work-stealing profile, a fiber can stop on one worker thread and
resume on another. Every value the runtime holds for a program may therefore
move to another thread, be used there and be destroyed there. That includes
the callbacks and values stored in an `IO`, fiber state between steps,
outcomes waiting to be joined, and the values in a `Ref`, `Deferred` or `Queue`. Plain data
such as `Int`, `String`, `List` and structs of these qualifies.

Mojo 1.2 has no `Send` or `Sync` traits, so the library checks what
reflection can see. A payload is rejected at compile time when its fields
reach a raw or borrowed `Pointer` through a struct that does not conform to
`ThreadTransferable`, from `fp.effects`. Conforming to the trait is your
claim that a type is safe anyway. `assert_thread_transferable[T]()` is a
stricter opt-in check that also rejects `ArcPointer` outside a conforming
struct.

<!-- example: docs/examples/async_thread_safety.mojo -->

`Counter` shares an `ArcPointer[Atomic[Int]]`, so every access to its target
is atomic, and it conforms to `ThreadTransferable`. A thousand fibers each
add one, and the program prints `atomic counter: 1000`. The same count
through a `Ref` prints `ref counter: 1000`. An `ArcPointer` to plain mutable
data would be a data race: its reference count is atomic, but its target is
not.

Both checks are heuristics, not proofs. They cannot see values captured
inside a closure, `Dict` values, or the payloads of `Variant`, `Tuple` and
`OwnedPointer`. The [async runtime guide](../guides/async-runtime.md#share-state-across-threads)
states the full contract. The [payload thread safety](../architecture/async-thread-safety.md)
page explains the check and audits the runtime's own shared structures.

## Write concurrent code generic over the family

The operations in this chapter are `IO` methods, but generic code can ask for
only the capabilities it uses, as the functions in
[chapter 11](capabilities.md) ask for `Ask` or `Stateful`. Each async
capability is a compile-time dictionary that forwards to an existing
operation:

| Capability | Operations |
|---|---|
| `Spawn` | `start[I]`, `join[I, T]`, `cancel[I, T]`, `never[I, A]`, `cede[I]`, `background[I]` |
| `Concurrent` | `make_ref[I]`, `get_ref[I, T]`, `set_ref[I]`, `update_ref[I]`, `modify_ref[I, A]`, `make_deferred[I, T]`, `complete_deferred[I]`, `get_deferred[I, T]` |
| `Timing` | `monotonic[I]()`, `real_time[I]()`, `timed[I](program)` |
| `Temporal` | `sleep[I]`, `timeout_to[I]`, `timeout_after[I]`, `timeout[I]`, `delay_by[I]`, `and_wait[I]` |

`Async[E]` provides all four for `IO[T, E]`. The synchronous `SyncIO[E]`
provides `Timing` but none of the others, because it has no fibers and cannot
suspend. A function written as `def f[I: Spawn & Temporal](...)` runs on any
provider of both, and a provider that lacks one is rejected at the call.

<!-- example: docs/examples/async_capabilities.mojo -->

The example fixes `A = Async[Int]` and calls each capability through it.
`make_ref[A](41)` creates a cell, and `BumpThenRead` updates it with
`update_ref` and reads it with `get_ref`, so the program prints `ref: 42`.
`start[A]` starts a child and `join[A, Int]` joins it, giving `joined: 7`.
`timed[A](sleep[A](...))` measures a 5 ms sleep on the monotonic clock, and
`real_time[A]()` reads the wall clock described in [chapter 12](io.md).
Generic signatures state what they admit in `where` clauses through each
provider's associated types; the
[async runtime guide](../guides/async-runtime.md#write-programs-generic-over-the-family)
gives the full contract, including `Defer`, `Raise`, `Cancel`, `Blocking` and
`EvalOn`.

## Where to go next

Continue with [running and testing async programs](running.md).
