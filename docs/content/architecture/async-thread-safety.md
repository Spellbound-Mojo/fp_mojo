# Async payload thread safety

This page documents the payload thread-safety contract for the work-stealing
runtime, audits runtime structures shared between threads, and describes compile-time
checks available in Mojo 1.2.

Because Mojo does not provide automatic `Send` or `Sync` traits, the library
establishes explicit contracts for thread transfer and checks what the compiler
can verify statically.

## Why the contract changes

On the current-thread profile, every fiber runs on the root polling thread, so
shared values are never touched by multiple OS threads concurrently. Under the
work-stealing profile:

- A fiber's run loop, and everything it owns, can run on worker A, park, and
  resume on worker B. Its state moves between threads with every steal.
- Two fibers that share a value can run at the same moment on different
  workers.
- Whatever drops the last owner of a value destroys it, on whatever thread that
  happens to be: a worker, a blocking-pool thread, or a foreign thread that
  completes an `IO.async` registration.

Moving a value between threads is safe whenever a queue hands it over with the
right ordering, as the runtime's queues will. The hazards are values that are
**shared** while unsynchronized and values that are **tied to one thread**.

## The contract

The proposed wording for the guide, after Rust's `Send` and `Sync`, stated for
the library's own vocabulary.

### What must be safe to move to another thread

Every value the runtime owns on a program's behalf must be **transferable**: it
may be moved to another thread, used there, and destroyed there. This covers:

1. Everything stored in an `IO` value: the program's callables (the functions
   and library callables given to `delay`, `map`, `flat_map`, `handle_error`,
   `guarantee`, and the rest), the values given to `pure`, the leaves given to
   custom-machine constructors, and the resources and finalizers of `Resource`.
2. Everything held in fiber state between steps: values bound by a
   continuation, an outcome waiting to be joined, the errors of a failure, and
   the state of a custom `Machine`.
3. Everything moved through a `Completion`: the outcome passed to `complete`
   and, through it, the value or errors it holds. A rejected payload is
   destroyed on the thread that offered it.
4. The functions given to `IO.blocking` and `IO.interruptible`, their results,
   and their errors, which move to and from blocking threads.
5. Values stored in `Ref`, `Deferred`, and `Queue`, which any fiber may take or
   copy out.

A type is transferable when none of its parts is tied to a thread. Plain data
(`Int`, `String`, `List`, `Dict`, `Optional`, structs of these) and values
uniquely owned through `OwnedPointer` are transferable when their elements are.
Not transferable: a raw `Pointer` (`UnsafePointer`, `OpaquePointer`) whose
target another thread may use or free without synchronization, a borrowed
`Pointer` into some other owner's state, a handle to a thread-local resource,
and an `ArcPointer` whose target is not *shareable* (below).

### How fibers may share mutable state

A value that two fibers can reach at once must be **shareable**: safe to use
from several threads at the same time. Fibers share mutable state only through:

- The library's synchronized owners: `Ref`, `Deferred`, `Queue`, `Semaphore`,
  `Signal`, `CancellationToken`, and `Completion`, and `Fiber` handles and
  `Supervisor` once the races listed in the audit are fixed. Their operations
  are ordered by locks or atomics, and each operation's effects happen before
  any operation that observes them.
- Types whose authors synchronize them: an `Atomic`, or a structure behind a
  lock that the author qualifies under contention.
- Immutable data shared through `ArcPointer`: its reference count is atomic,
  so copies may live on several threads as long as no thread mutates the target.

Callbacks run under a coordination owner's lock (`Ref.modify`, `Ref.update`,
and the destructors of replaced state) must still not reenter the same owner,
and should be short: under parallel execution other workers wait for that lock.

### What becomes a data race

Code that was correct on the single-threaded runtime becomes undefined behavior
under the work-stealing profile when fibers share an unsynchronized mutable
value. The main case is an `ArcPointer` to mutable data, with copies held by
two fibers that mutate it (`arc[] += 1`, `arc[].append(x)`). Mojo's own
documentation for `ArcPointer` says the count is thread-safe but references to
the target are not. The probe below shows the effect.

Other cases that silently change meaning:

- A raw `Pointer` stored in a payload and used from fibers on different workers.
- A custom `Machine`, or a payload's destructor, that touches a global or a
  thread-local resource, assuming the thread that created it is the thread that
  polls or destroys it.
- A borrowed view into another fiber's state, which is already forbidden
  because erasure drops origins, now also crossing threads.

The guide should say this prominently, with the current-thread profile as the
alternative: code that keeps unsynchronized sharing runs unchanged there,
because one worker runs every fiber of the root.

### Evidence

`experiments/async-state-machines/probes/thread_arc_race.mojo` has two OS
threads each increment a shared `Int` 100,000 times through their own copy of
one `ArcPointer[Int]`. At O0, three runs counted 119,839, 130,517 and 110,730
of 200,000 increments. With the counter as an `ArcPointer[Atomic[Int64]]`, the
count was 200,000.

## Audit of shared runtime state

Each entry names the owner, its synchronization today, what changes under
parallel execution, and what it needs. "Confined" means used only by the root's
polling thread today. Two facts hold throughout:

- `Atomic` operations default to sequentially consistent ordering on CPUs
  (`_DEFAULT_MEMORY_ORDERING` and `_DEFAULT_COMPARISON_ORDERING` in Mojo 1.2's
  `std/atomic/atomic.mojo`). The cell locks below therefore order everything
  done under them, and do more than needed.
- `ArcPointer` counts references with release decrements and an acquire fence
  before destruction, so dropping copies on different threads is safe.
  `ArcPointer.count()` is a relaxed load.

### Erasure

| Owner | Today | Under parallel execution | Needs |
|---|---|---|---|
| `_Erased` (`src/fp/_internal/erased.mojo`) | Owns one hidden value inline or in an `OwnedPointer`; destroyed through a stored thin function. No sharing. | Moves between workers inside run loops and records; destroyed on whichever thread drops it. The box hides the type, so later code cannot check it. | Nothing for the box itself, which is transferable when its payload is. Its typed constructor, the only place where every erased payload's type is known, runs the payload check (see [implementation details](#implementation-details)). |
| `_ErasedMachine` (`src/fp/effects/_async/erased.mojo`) | `_Erased` plus a thin poll function. | Same; the machine is polled by one worker at a time. | Same. |

### Fibers

| Owner | Today | Under parallel execution | Needs |
|---|---|---|---|
| `_FiberRecord` (`src/fp/effects/_async/fibers.mojo`), shared through `ArcPointer` by the handle, its `_Claim`, `_Join`, `_Delivery`, `_FirstDone`, `_CancelFiber`, `_RequestCancel`, `Supervisor`, and its owner's scope | `token` and `signal` are synchronized. The outcome lives in a lock-free one-shot slot (`src/fp/_internal/oneshot.mojo`); `report` and `reporter` are fixed at creation. | Complete, join-take, claim release and a dropped delivery are transitions of the slot's atomic state: exactly one party takes or disposes of the outcome, and `done` is an acquire load. | Verified under concurrent completion, joins, claim drops, and dropped deliveries across OS threads (`race_record`). |
| `_Inbox` (fibers) | Superseded by scheduler run queues. | Fibers on different workers spawn concurrently. | A started fiber is pushed directly to the scheduler queue; spawn paths are per-worker or synchronized. |
| `_Fibers` table and `_FiberEntry`; the scheduler's fiber table | Diagnostic table uses lock-free slots (`src/fp/_internal/fiber_slots.mojo`). | Fiber start and end pop and push a free-index stack and publish an entry with no lock. | Snapshots read live tasks' states, so `Driver.fibers()` stays between polls on the driving thread; a `Runtime`'s roots share their tables, allowing cross-thread inspection (`Runtime.fibers()`). |
| `_SupervisorState` (`src/fp/effects/_async/supervisor.mojo`); `_Stop` is gone | Immutable after creation. Supervised fibers are the children of the supervisor fiber's scope, on a closable lock-free stack (`src/fp/_internal/closable_stack.mojo`); the stop request is a `CancellationToken`. | `supervise` pushes unless the stack is closed; release closes it with one atomic step. A supervise that loses the race returns an already-canceled fiber whose program never runs under atomic race condition rules. | Verified with concurrent adoption racing against scope release across OS threads (`race_supervisor`). |
| `Fiber` handles (async) | Hold the record. | Transferable once the record is synchronized. | Verified safe for cross-thread movement. |
| Synchronous `Fiber` and `_FiberState` (`src/fp/effects/fibers.mojo`) | Already cross-thread: `done` is atomic, and only the worker touches `program` and `result` before the join. | Unchanged. | Thread-safe by design. |

### Wake registry, signals, and timers

| Owner | Today | Under parallel execution | Needs |
|---|---|---|---|
| `Signal` (`_EventState`, `src/fp/_internal/waking.mojo`) | Revision and subscriber list behind the `_Cell` spin lock; `notify` copies the wakers and wakes them outside the lock. | Notified from workers and foreign threads; fibers subscribe on other workers. | Fully qualified cross-thread signaling contract, ordering notifications and subscriber wakeup (`foreign_signal`). |
| `_Subscription` | Retires its entry under the signal's lock; aborts on double retirement. | Dropped on any worker. | Nothing beyond `Signal`'s qualification. |
| `_Runtime` and `_ReadyState` (`waking.mojo`) | One tree of generation-checked nodes and the root's timer heap behind one `_Cell` lock. | Every wake and timer for every fiber would contend for one lock. | Partitioned per-fiber registry and per-worker timer heap, preserving generation checks. The root wake hook runs outside the lock, as `Signal.notify` wakes outside its own. |
| `_Waker` | Copies the runtime handle, ticket, and epoch; `wake` takes the registry lock and checks the generation. | Called from any thread. | Unchanged; the epoch check already rejects stale wakes. |
| `_Clock` and `Clock` (`waking.mojo`, `src/fp/effects/_async/host.mojo`) | The system clock reads `monotonic()`. A manual clock is an `Instant` behind the cell lock. | Read from every worker. | Nothing for the system clock. Under `TestControl` the manual clock is advanced by the controlling thread while workers read it; that profile stays current-thread. |

### Cells and coordination

| Owner | Today | Under parallel execution | Needs |
|---|---|---|---|
| `_Cell`, `_Guard`, `_try_lock`, `_lock_metadata` (`src/fp/_internal/cells.mojo`) | A one-byte spin lock: compare-exchange to acquire, store to release, both sequentially consistent. `_lock_metadata` spins with `sleep(0.0)`. | Correct as a mutex: acquisition and release order the guarded state. Spinning wastes a worker under contention; `sleep(0.0)` is a yield. | Borrowed guards (`_lock_cell`) acquire with ACQUIRE and release with RELEASE; `_Guard` stays sequentially consistent for scheduler handshakes. All lock word orderings are audited ([ordering audit](#memory-ordering-audit)). |
| `_lock` (`src/fp/effects/coordination.mojo`) | Spins, then yields, through the shared `_acquire_lock` in `cells.mojo`, asking its context between yields whether cancellation stops the wait. No fixed sleep. Used by the synchronous family and `Permit.__deinit__`; `Completion` no longer locks. | A worker that runs a `Permit` destructor while contended yields instead of sleeping 1 ms. | Verified with non-blocking spin-yields. |
| `Ref`, `Deferred`, `Queue`, `Semaphore`, and `Permit` (`coordination.mojo`, `src/fp/effects/_async/coordination.mojo`, the engine's `Ref` and `Deferred`) | One `_Cell` per owner plus a `Signal`. Async attempts take `_try_lock` and return a runnable `Wait()` when it is held (`_attempt` in `_async/attempts.mojo`). User callbacks and replaced-state destructors run under the lock. | Qualified under contention from OS threads for the synchronous family (`test_coordination`). In the async family, a fiber that finds the lock held is rescheduled immediately, so a long callback under the lock makes other workers busy-poll. `Deferred.get` copies the value, so copies of a `T` holding an `ArcPointer` are shared. | Safe under multi-threaded execution; callbacks under locks are required to remain short. |
| `_ExclusiveCell` (`src/fp/_internal/exclusive.mojo`, iteration branching) | An atomic gate that aborts on overlapping access. | Unchanged: it already detects concurrent use and aborts rather than racing. | Nothing. |

### Callbacks, cancellation, and accounting

| Owner | Today | Under parallel execution | Needs |
|---|---|---|---|
| `Completion` (`src/fp/effects/_async/callbacks.mojo`); `_CompletionState` is gone | The decision is a lock-free one-shot slot: the first `complete` claims it, writes and publishes the outcome (release), and the registration takes it (acquire). A rejected outcome is destroyed on the calling thread with nothing locked. | Completed from foreign and blocking threads; the waiting fiber takes the outcome on any worker. | Resolved via lock-free one-shot slot (`foreign_completion`). |
| `Callback.counted` and `_Budget` (`src/fp/effects/_io_core.mojo`) | The transition slice (`remaining`, `consumed`) belongs to the executor that runs the loop and is touched only on its thread. Thresholds, `report` and `reporter` are read-only after construction. `registrations` is one atomic counter on `_Scheduler`, changed with release and read with acquire. | Each worker owns its slice (the executor's `begin_run` hook refills it per task run); a `Callback` dropped on any thread decrements the shared counter. | Atomic registration counter decremented on callback drop and acquired by deadlock detection (`race_registrations`). |
| `CancellationToken` (`_io_core.mojo`) | An atomic flag set by compare-exchange, then a `Signal` notification. | Canceled from any thread. | Atomic cancellation flag paired with Signal wakeup (`foreign_signal`). |
| `IOContext` (`_io_core.mojo`) | Copied per run loop; `_region` is an `ArcPointer[Int]` compared by address only. | Moves with its run loop. | Nothing; `_region` is never mutated. |
| `_Reporter` and `IORuntimeConfig.reporter` (`src/fp/effects/_async/kernel.mojo`) | A thin function called when a record disposes of an unjoined failure; the default prints to `stderr`. | Called from whichever thread disposes, possibly from two at once. | The reporter can be invoked concurrently from any thread without locking. |
| `Driver`, `TestControl`, `_Driver` (`host.mojo`, `kernel.mojo`) | Confined to the polling thread; `Driver` is linear. | `Driver` embeds the current-thread profile only. | Host notifier can be signaled across threads; the host verifies thread safety. |

### Elsewhere in the library

| Owner | Today | Under parallel execution | Needs |
|---|---|---|---|
| `Node` (`src/fp/adt/data.mojo`) | Immutable data behind `ArcPointer`. The destructor releases children in a loop when `count() == 1`. | Immutable sharing is safe. After the relaxed `count() == 1` check, the destructor only reads the node, copying its children into a work list, and each node is then released through `ArcPointer`'s own release decrement and acquire fence, which orders other threads' last uses before destruction. Rust's `Arc::get_mut` needs an extra acquire because it grants mutation; this path does not mutate. When the last two owners drop at once on two threads, both can see a count of 2, and the final release falls back to recursive destruction, which can overflow the stack on deep values. | No fence. Recursive destruction under concurrent drops is a stack-safety issue to document or fix, not a race. |
| `Resource` and the finalization scopes | Hold the program's acquired value and finalizers as payloads. | Transferable when their payloads are. | Covered by the payload contract. |

The three potential data races identified during concurrency design (`_FiberRecord`,
`_SupervisorState`, and `_Budget`) are resolved with lock-free terminal
states, ensuring race-free execution before fibers run in parallel.

## What Mojo 1.2 can check at compile time

### Send and Sync in Mojo

Mojo 1.2.0 (released on 2026-10-22) has no `Send`, `Sync`, `Sendable`, or
other thread-safety marker, and no auto traits that the compiler derives from a
type's fields. Sources:

- Modular's draft proposal
  [Designing async in Mojo](https://github.com/modular/modular/blob/main/Mojo/proposals/async-design.md)
  (dated 2026-10-01) lists among the features it intends to build "a
  thread-safety model, similar to Rust's `Send`/`Sync` or Swift's `Sendable`,
  so the compiler can check which values are allowed to cross threads inside
  tasks". It gives no design or date; that model is not among its committed
  decisions. The tracking issue,
  [modular/modular#7211](https://github.com/modular/modular/issues/7211), does
  not mention thread safety.
- The [roadmap](https://docs.modular.com/mojo/roadmap) lists first-class
  `async` support as in progress and struct extensions as not started; it has
  no thread-safety entry.
- The standard library's `ArcPointer` documentation says the reference count
  is thread-safe "but references returned to the underlying data are not
  thread-safe" (`std/memory/arc_pointer.mojo` at `mojo/v1.2.0`). The safety is
  documented, not typed.
- The release notes from 24.x to 1.2 and the nightly changelog mention none of
  `Send`, `Sync`, `Sendable`, or data races.
- A community proposal,
  [Structured Async for Mojo (#3945)](https://github.com/modular/modular/pull/3945),
  required `Send` and `Sync` traits. Modular closed it on 2026-09-29, saying
  the team is designing async internally and will fold it into that design.

The library therefore treats a future `Send`/`Sync` as likely but unscheduled;
the library is designed so that future standard traits can seamlessly replace
current internal checks.

### Related language facilities

- **Reflection** (`reflect[T]`, in the prelude since 1.0): `is_struct`,
  `name`, `base_name`, `field_count`, `field_types`, `field_names`, `field_at`,
  and `annotations`, all usable in generic code once `T` is specialized.
- **Trait checks:** `conforms_to(T, Trait)` and `downcast[T, Trait]`, usable in
  `comptime if` and `comptime assert`.
- **Annotations:** an experimental `@__annotation(...)` decorator readable
  through `reflect[T].annotations()`, with no stability guarantee
  ([proposal](https://github.com/modular/modular/blob/main/Mojo/proposals/annotations.md)).
- **No struct extensions:** a library cannot add a conformance to a type it
  does not own, so a marker trait can never be declared for `List`, `String`,
  or `ArcPointer`.
- **Precedent:** the standard library's `DevicePassable` encoding walks field
  trees with `reflect` (`_contains_device_passable_field` in
  `std/builtin/device_passable.mojo`), and `Defaultable`, `Equatable`,
  `Hashable`, and `Writable` derive default implementations from fields.

### Probes

The probes are in `experiments/async-state-machines/probes/`. Build each with
`pixi run mojo build -I src <file> -o <out>`; the rejection probe also needs
`-I experiments/async-state-machines/probes`.

| Probe | Shows |
|---|---|
| `thread_reflect_walk.mojo` (runs) | What a recursive field walk sees in common payload types |
| `thread_payload_check.mojo` (runs) | A conservative classifier built from what works, with its holes |
| `thread_payload_reject.mojo` (must be rejected) | The classifier rejecting a payload through a generic caller |
| `thread_arc_race.mojo` (runs) | The `ArcPointer` data race the contract forbids |
| `erased_borrow.mojo` (compile-time rejected) | Erasing a machine that borrows a local whose origin the carrier drops |

What works:

1. **Recursive field walks in generic code.** A function generic over
   `T: AnyType` can walk `reflect[T].field_types()` recursively with
   `comptime for`, and the walk is evaluated once `T` is known. Every branch
   must be an `elif`: code after a `return` inside `comptime if` is still
   elaborated, and `field_types()` on a type that is not a struct fails to
   compile. `Int` and `Bool` are structs whose single field is a non-struct
   MLIR type; function types are reported as a struct (`__MLIRType`) holding a
   non-struct. `field_names()` failed to elaborate on some nested standard
   types (in `Array`'s fill), so the probes use indices.
2. **Finding pointers.** `UnsafePointer`, `OpaquePointer`, and `Pointer` are
   one struct in 1.2 (`UnsafePointer` is a deprecated alias), with
   `base_name() == "Pointer"`, so a walk finds every raw or borrowed pointer
   field, including those of a borrowing struct such as `Borrowing[o]` holding
   `Pointer[List[Int], o]`.
3. **Finding shared ownership.** `base_name()` identifies `ArcPointer` and
   `WeakPointer`.
4. **Telling the standard library from user code.**
   `name[qualified_builtins=True]()` starts with `std.` for standard types;
   user structs are qualified by their module (`thread_payload_check.Shared`).
5. **Elements of standard containers.** `downcast[T, IterableOwned]
   .IteratorOwnedType.Element` yields the element type of `List` and
   `Optional` in generic code, so the walk can enter them.
6. **Opt-in markers.** `conforms_to(T, Marker)` on a user-declared empty trait
   works in generic code, so an author can assert that a type synchronizes
   itself, and the walk stops there.
7. **Rejection with a useful message.** A `comptime assert` over the
   classifier inside a generic `admit[T]` rejects a payload instantiated through
   another generic function (`relay[T]`), and the diagnostic names the type:
   `constraint failed: payload may be thread-confined: thread_payload_check.Shared`.
8. **Cost.** The classifier probe with 15 types builds in about 3 s, almost
   all of it the fixed cost of compiling and linking; a reflection walk is
   elaborated once per distinct type.

The classifier reports, for each type:

| Type | Result |
|---|---|
| `Int`, `String`, `List[String]`, a struct of `String`, `List[Int]`, and `Optional[String]` | No hazard |
| A struct conforming to the marker, holding `ArcPointer[Atomic[UInt64]]` | No hazard (asserted by its author) |
| A struct with a `Pointer[Int, MutUntrackedOrigin]` field | Raw pointer |
| A struct borrowing `Pointer[List[Int], o]` | Raw pointer |
| A struct holding `ArcPointer[List[Int]]`, nested or not; `List` of it; `Optional[ArcPointer[Int]]` | Shared ownership |
| `Dict[String, Shared]`, `Tuple[Int, Shared]`, `OwnedPointer[Shared]` | **No hazard (missed)** |
| `ArcPointer[Atomic[UInt64]]` | **Shared ownership (false positive)** |

What does not work:

1. **Reading a pointer's or a container's parameters in generic code.** For a
   concrete type, `reflect[ArcPointer[Int]].field_at[0].T.T` names
   `_ArcPointerInner[Int]`. In a generic function, `T.T` on a type known only
   as `AnyType` is rejected while parsing (`'AnyType' value has no attribute
   'T'`), and `downcast` needs a trait that `Pointer` conforms to and that
   exposes `T`, which does not exist. So the walk cannot see what an
   `ArcPointer`, `OwnedPointer`, or `List`'s buffer points to, except through
   iteration traits.
2. **Origins.** Type names print every origin as `{}`, and an origin value has
   no equality (`'MutOrigin' does not implement the '__eq__' method`). The walk
   cannot tell an owned allocation (`MutUntrackedOrigin`) from a borrow; it can
   only read mutability from the name. Type equality against a fully spelled
   `Pointer[X, MutUntrackedOrigin]` works, but needs `X`.
3. **Opaque storage.** `Optional`, `Variant`, and `Tuple` keep their payloads in
   MLIR storage that reflection reports as non-struct fields. `Optional` is
   reachable through `IterableOwned`; `Variant` and `Tuple` are not, and `Dict`
   iteration yields only keys.
4. **Conformance for types the library does not own.** Without extensions,
   `ArcPointer[Atomic[...]]` or `ArcPointer` to immutable data cannot be marked
   as shareable; only a wrapper struct can.
5. **Erased payloads.** `_Erased` stores a heap address in `UInt64` words, so
   an `IO[Int, Int]` classifies as hazard-free whatever it holds. A check must
   run where the payload's type is still known.
6. **Library owners trip the walk.** `Ref`, `Deferred`, `Queue`, `Semaphore`,
   `CancellationToken`, `Completion`, `Fiber`, and `Clock` all hold an
   `ArcPointer` and classify as shared ownership. The library would mark them.
7. **Thread sanitizer.** `mojo build --sanitize thread` builds an executable
   linked with the system `libtsan.so.2`, but in this container the runtime
   aborts at startup (`ThreadSanitizer: mmap at bad address`), with or without
   address-space randomization. A C program built here with
   `gcc -fsanitize=thread` reports the same race correctly, so the failure is
   specific to Mojo executables in this environment. A sanitizer run needs
   another host or a fix, and remains open.

So Mojo 1.2 cannot prove that a payload is transferable. It can find the two
most common hazards, raw pointers and `ArcPointer`, in user-defined structs and
in `List` and `Optional`, with known holes and false positives.

## Recommendations

1. **Adopt the contract** above in the async guide and the scheduler page
   with the `ArcPointer` race and current-thread profile explained.
   Payloads stored in `IO`, fiber state, and coordination owners must be
   transferable, and shared ones must be shareable.
2. **Guarantee race-freedom:** `_FiberRecord`'s outcome and release state,
   `_SupervisorState`, and `_Budget.registrations` are fully synchronized.
   `Node` requires no fence (see the audit), and multi-threaded stress clients
   verify these paths.
3. **Adopt one compile-time check, narrowly: raw pointers in user structs.** A
   payload type whose field tree reaches a `Pointer` through a struct outside
   the standard library is rejected unless that struct conforms to an opt-in
   marker trait. The check belongs in the canonical erasure owner,
   `_Erased.__init__[T]`, which every payload reaches with its type still known;
   no public overload needs its own copy. It also catches the borrowed-view
   case that erasure cannot check today (the `erased_borrow.mojo` probe), so it
   serves the existing owned-state precondition as well as threads. Cost to
   users: a custom container that owns memory through a raw pointer must
   conform to the marker, and its author takes on the obligation explicitly.
   The marker's name and module are public API and need a decision; a name that
   cannot clash with a future standard `Send`, such as `ThreadTransferable`,
   avoids a later rename conflict.
4. **Do not reject `ArcPointer` by default.** Immutable sharing and
   `ArcPointer[Atomic[...]]` are correct and common, the walk cannot see the
   target type, and `Dict` values, `Variant`, `Tuple`, and `OwnedPointer`
   payloads hide hazards anyway. A default rejection would be both noisy and
   unsound. Instead, publish the classifier as an opt-in assertion that users
   and the library's own tests can call on their payload types, such as
   `assert_thread_transferable[T]()`, which rejects raw pointers and shared
   ownership unless marked. The library's synchronized owners conform to the
   marker.
5. **Replace the checks when Mojo adds `Send` and `Sync`.** Keep the marker
   and the check in one private owner, so that adopting the standard traits is
   a change to that owner and to the marker's definition, with a migration for
   users who conformed to it.
6. **Measure before adopting the check in `_Erased`.** Elaboration cost for
   every erased payload in the package, measured with an empty compile cache
   as the development guide describes, and the list of library-internal types
   the check rejects, found with a package precompile and the suite. Internal
   types that hold a borrowed `Pointer` and are erased deliberately (if any)
   conform to the marker with a comment explaining why they are safe.

## Adopted design decisions

The runtime's thread-safety model adheres to the following principles:

1. **Marker.** The public marker trait `ThreadTransferable` explicitly marks types
   safe to transfer across worker threads.
2. **Scope.** The check lives in `_Erased` and applies to synchronous and
   async families alike, verifying structs before multi-threaded dispatch.
3. **Held coordination locks.** Contention is measured under
   the work-stealing pool first. Waiting on the owner's signal after a failed
   `_try_lock`, with a notification on unlock, provides backpressure if workers
   encounter contention.
4. **Thread sanitizer.** It does not run for Mojo executables in this
   container, so race detection is verified through multi-threaded stress suites.
5. **Synchronous scope.** The synchronous `IO[E]`
   family, `unsafe_start` included, keeps its programs typed and never reaches
   `_Erased`, so the check covers erased payloads only and synchronous programs
   are unaffected; `unsafe_start` keeps its documented obligations.
6. **Borrowed views.** `_Erased`'s documented
   precondition narrows to owned state, and a borrowed `Pointer` in a user
   struct is rejected even when the carrier's value or error type keeps its
   origin. Standard views such as `Span` are trusted and pass.

## Implementation details

The runtime implements recommendations 3 to 5 with the decisions above.

**The check.** `_Erased.__init__[T]` asserts, once for every consumer, that
`T`'s field tree reaches no `Pointer` through a struct that does not conform to
`ThreadTransferable`. The walk, the marker and the opt-in assertion live in
one private owner, `src/fp/_internal/thread_safety.mojo`, so adopting a
standard `Send` and `Sync` later changes only that module and the marker. The
walk uses a static compile-time classifier: it stops at a conforming type,
trusts the standard library's own fields, enters standard containers only
through `IterableOwned`, and walks every other struct's fields by index. The
diagnostic names the erased type, the hazard and the struct that holds it:

```text
constraint failed: cannot erase `app.Outer`: it reaches a `Pointer` field of
`app.Raw`, which is not ThreadTransferable. An erased payload must own its
state and be safe to move to, use on and destroy on another thread. Own the
state instead of pointing to it, or conform the struct to
`fp.effects.ThreadTransferable` to claim that it is safe.
```

**Public API**, exported from `fp.effects`: the marker trait
`ThreadTransferable`, and `assert_thread_transferable[T]()`, which also
rejects `ArcPointer` and `WeakPointer` outside a marked struct. The library's
synchronized owners conform: `Ref`, `Deferred`, `Queue`, `Semaphore` and
`Permit` of both families, the async `Fiber`, `Supervisor`, `Completion`,
`Clock`, `CancellationToken` and `BlockingPool`. Marking the public owner is
enough, because the walk stops there. `IOContext` is not marked: it holds an
`ArcPointer` region and budget and is not a sharing owner.

**Measurements** (before adoption, empty compile cache, one run each, back
to back on nightly `4388584`). The package precompile is unchanged (86.0 s
without the check, 85.3 s with it), because a precompile never instantiates
the check. Clients pay about 2 to 3 s at O0: `io_operations` 41.8 s to
43.9 s, `async_coordination` 43.3 s to 46.5 s, `public_resources` 46.6 s to
48.3 s; peak memory rose by at most 3%.

**What it rejected.** A build of all 175 async clients, fixtures, stress
programs and examples found no library type. The library's raw-pointer owners
(`_OneShot`, `_ClosableStack`, `_FiberSlots`, the blocking pool's core, the
scheduler queues, parking, timers and poller state) sit behind an `ArcPointer`
or never reach erasure. Two test-side types were rejected:

- `foundation.Borrowed`, a machine holding a borrowed `Pointer` whose origin
  its `Span` value and error types keep, used by five origin clients. It now
  holds a `Span`, a standard view the check trusts (see borrowed views in
  [adopted design decisions](#adopted-design-decisions)), so the clients keep
  their origin coverage.
- `wstp_support.Tracked`, whose pointer into a ledger outliving every element
  is touched only atomically, so it conforms to the marker with a comment.

No rejection fixture's expected diagnostic changed.

**Clients.** `public_thread_transferable` erases a marked raw-pointer owner,
standard payloads and an unmarked `ArcPointer` holder, and asserts that the
library's owners are transferable. The fixtures `public_reject_payload_pointer`
(a user struct with a raw `Pointer` in `IO.pure`), `reject_payload_borrow`
(the `erased_borrow` pattern) and `public_reject_transferable_shared`
(`assert_thread_transferable` on an unmarked `ArcPointer` holder) pin the
diagnostics.

**Known holes.** `Dict` values, `Variant`, `Tuple` and `OwnedPointer`
payloads, closure captures, which reflection does not show, and standard views
such as `Span`. The guide states them in
[share state across threads](../guides/async-runtime.md#share-state-across-threads).

## Memory ordering audit

Every structure shared across threads documents the ordering of each atomic
operation and its formal invariants in its own docstring. The table below lists
each structure, the owning module, cross-thread operations, where orderings are
specified, and the stress test clients that exercise it across threads (`wstp_stress`
provides a randomized mix of spawns, joins, cancellations, races, `both`,
`par_traverse`, timers, blocking calls, and foreign wakes on the pool).

| Structure | Owner | Cross-thread operations | Orderings documented | Stress clients |
|---|---|---|---|---|
| One-shot slot (`_OneShot`, `_ShotCell`): fiber records, `Completion`, pool roots | `_internal/oneshot.mojo` | `try_claim`, `publish`, `put`, `take`, `release`, `close` | Module docstring | `race_oneshot`, `race_record`, `foreign_completion`, `wstp_wakes`, `wstp_stress` |
| Closable stack (`_ClosableStack`): scopes, `Supervisor`, `AsyncPar`'s group | `_internal/closable_stack.mojo` | `push`, `push_first`, `close`, `take_all`, `prune` | Module docstring | `race_stack`, `race_stack_take`, `race_supervisor`, `race_par_group`, `wstp_stress` |
| Fiber slots (`_FiberSlots`) | `_internal/fiber_slots.mojo` | Register and release on any worker, chunk growth, snapshots of shared tables | Module docstring | `public_runtime` (snapshots racing completion), `fiber_snapshot` and `fiber_churn` on the pool, `wstp_ownership` |
| Task state (`_TaskHeader`) | `_internal/waking.mojo` | `begin_run`, wakes (`_schedule`), a run's end (`_Runtime.park`), `finish`, `done` | `_TaskHeader` docstring | `wstp_wakes`, `wstp_lifo`, `wstp_ownership`, `wstp_stress` |
| Scheduler words (`_SchedulerWords`) | `_internal/waking.mojo` | Foreign `push` and `notify_host` (notify-or-close), `close`, the wake hook, `polling`, `registrations` | `_Scheduler` docstring; [scheduler words](async-scheduler.md#the-schedulers-words) | `run_parks`, `foreign_completion`, `race_registrations`, `wstp_wakes`' late completions |
| Wake registries, `_Waker`, `Signal`, the root's ready queue, timer heap and manual clock | `_internal/waking.mojo` | Wakes, timer fires, subscriptions and notifies from any thread | Module docstring: each behind its own `_Cell` lock | `foreign_signal`, `foreign_completion`, `wstp_wakes`, `wstp_worker_timers` |
| Cell locks (`_Cell`, `_Guard`, `_CellGuard`, `_lock_until_canceled`) | `_internal/cells.mojo` | Acquire and release from any thread | Module docstring, per operation | `race_oneshot` (lock held through a guard's last use), `test_coordination`, the coordination clients on the pool |
| Scope counts (`_ScopeCounts`) | `_async/fibers.mojo` | `adopt`, `child_completed`, `count`, the owner's slot | `_ScopeCounts` docstring | `race_supervisor`, `wstp_ownership`, `fiber_drain` on the pool, `wstp_stress` |
| `AsyncPar` completion group (`_ParGroup`, `_ParNode`) | `_async/engine.mojo` | Announcements from children, the waiter's takes | `_ParGroup`, `_ParNode` docstrings | `race_par_group`, the `par_*` clients, `wstp_stress` |
| Local ring (`_LocalQueue`) | `_async/scheduling/local_queue.mojo` | Owner's enqueue, dequeue and spill; thieves' `steal_into`; length hints | Module docstring | `wstp_queues`, `wstp_parallel`, `wstp_lifo`, `wstp_stress` |
| External queue (`_ExternalQueue`) | `_async/scheduling/external_queue.mojo` | Push, spill, pop and refill under stripe locks; published lengths | Module docstring (verified guard lifetimes) | `wstp_queues`, `wstp_wakes`, `blocking_pool`, `wstp_blocking`, `wstp_stress` |
| Parking (`_Parking`) | `_async/scheduling/parking.mojo` | Worker transitions, notifiers' claims, lazy starts, shutdown's stops | Module docstring | `wstp_parking`, `wstp_wakes`, `wstp_shutdown` |
| Timer heap (`_TimerHeap`) | `_async/scheduling/timer_heap.mojo` | Owner's insert, fire and pack; `cancel` and `steal_into` from any thread | Module docstring | `wstp_timers`, `wstp_worker_timers`, `wstp_stress` |
| Pool words and worker slots (`_PoolWords`, `_WorkerSlot`, `_WorkerTimers`, `_RootDone`) | `_async/pool.mojo` | Poller address, thread start, `closing`, heap opening, the thread cache's install, diagnostic counts, a root's completion handshake | Module docstring; [memory ordering](async-scheduler.md#memory-ordering) | `wstp_shutdown`, `wstp_wakes`, `wstp_blocking`, `wstp_worker_timers`, `public_runtime` |
| Poller (`_Poller`, `_WakeState`, `_RegistrationWords`) | `_async/polling.mojo` | `interrupt`, `close`, the pipe's users, `_release_registration` | Module docstring | `poller`, `run_parks`, `descriptor_readiness`, `syncio_waits`, `wstp_worker_timers` |
| Blocking pool core (`_PoolCore`, `_Calls`, the root's slot) | `_async/scheduling/blocking_pool.mojo` | Submit, idle list, retirement, `close`, in-flight counts, the slot's install | Module docstring and root hook notes | `blocking_pool`, `capability_blocking`, `wstp_blocking` |
| Blocking hand-off and thread cache (`_Blockers`) | `_async/pool.mojo`, hook (b) | Hand-off, the cap, a slot's change of thread | Pool docstring; [blocking hand-off](async-scheduler.md#blocking-hand-off) | `wstp_blocking` |
| Interruptible call (`_Interrupt`) | `_async/blocking.mojo` | The function's return against the fiber's withdrawal, under `_lock_cell` | `cells.mojo`; `CancellationToken` | `wstp_blocking`, `syncio_waits`, `capability_blocking` |
| Runtime roots (`_RuntimeCore`) | `_async/runtime.mojo` | Add, remove and copy live roots under a `_Cell` | Module docstring | `public_runtime`, `wstp_shutdown` |
| `CancellationToken` | `effects/_io_core.mojo` | `cancel`, `requested`, the poller bridge | `CancellationToken` docstring | `foreign_signal`, `syncio_waits`, `wstp_stress` |
| `Completion` and the registration count (`_Registrations`) | `_async/callbacks.mojo`, `_internal/waking.mojo` | `complete` from any thread; increments and drops | `Completion`, `_Registrations` docstrings | `foreign_completion`, `race_registrations`, `wstp_wakes` |
| Coordination owners (`Ref`, `Deferred`, `Queue`, `Semaphore`, `Permit`) | `effects/coordination.mojo`, `_async/coordination.mojo` | Locked updates and signals from any fiber | `cells.mojo` and `Signal` | `test_coordination` (OS threads); `async_coordination` and the `coordination_*` clients on the pool |
| Synchronous `Fiber` (`_FiberState`) | `effects/fibers.mojo` | `done` against the worker's result | `_FiberState` docstring | `test_fibers` |
| Exclusive cell (`_ExclusiveCell`) | `_internal/exclusive.mojo` | The gate's take and release | Module docstring | None across threads; `test_iteration_branching` checks reentry on one thread |

**Fixes and invariants.** The audit ensures strict guard lifetime retention:
`push` and `_push_ring` in `_ExternalQueue` keep the guard alive past published length stores (`_ = guard^`),
guaranteeing the lock orders the stores and prevents stale lengths from being read by parking workers.

**Notes.**

- `_LocalQueue`, `_TimerHeap`, and other concurrently shared structures take immutable `self` in all methods; owner-only state lives in segregated allocations (`_HeapOwner`, `_ChunkDirectory`) to avoid compiler `noalias` assumptions that could drop atomic updates.
- The sequentially consistent `_Guard` orderings stay: the ready queue's lost-wake handshake with `polling` relies on them.
- Because thread sanitizers require specific environment support, stress suites provide empirical concurrency validation.
