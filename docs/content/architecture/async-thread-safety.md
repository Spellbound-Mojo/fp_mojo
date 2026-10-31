# Async payload thread safety

This page is the research for stream S7 of the
[advanced async plan](async-advanced-plan.md#passes-12-and-13-together):
Pass 13 design item 7 and step 13e. It proposes the payload thread-safety
contract for the work-stealing runtime, audits every runtime structure that is
or will be shared between threads, reports what Mojo 1.2 can check at compile
time, with probes, and recommends what the library should adopt. Nothing here
changes library behavior yet. The plan's decisions and progress sections record
what is adopted.

Pass 12 decision 3 stands: Mojo has no `Send` or `Sync` proof, so the library
documents the caller's obligation, as `unsafe_start` already does, and checks
only what the compiler can establish.

## Why the contract changes

Today every fiber of a root runs on the root's polling thread, so values that
fibers share are never touched by two threads at once. Under Pass 13's
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
| `_Erased` (`src/fp/_internal/erased.mojo`) | Owns one hidden value inline or in an `OwnedPointer`; destroyed through a stored thin function. No sharing. | Moves between workers inside run loops and records; destroyed on whichever thread drops it. The box hides the type, so later code cannot check it. | Nothing for the box itself, which is transferable when its payload is. Its typed constructor is the only place where every erased payload's type is known, so it is the natural site for a payload check (see the recommendations). |
| `_ErasedMachine` (`src/fp/effects/_async/erased.mojo`) | `_Erased` plus a thin poll function. | Same; the machine is polled by one worker at a time. | Same. |

### Fibers

| Owner | Today | Under parallel execution | Needs |
|---|---|---|---|
| `_FiberRecord` (`src/fp/effects/_async/fibers.mojo`), shared through `ArcPointer` by the handle, its `_Claim`, `_Join`, `_Delivery`, `_FirstDone`, `_CancelFiber`, `_RequestCancel`, `Supervisor`, and the host table | `token` and `signal` are synchronized. `outcome`, `done`, `released`, `report`, and `reporter` are plain fields, written by the host and read by joiners, all confined. | **Data race.** The child completes on one worker (`_Fibers.complete` writes `outcome`, sets `done`, then notifies) while a joiner on another worker reads `done` and takes `outcome` (`_Join.poll`), a claim drops on a third (`_Claim.__deinit__` sets `released` and calls `settle`), or `_Delivery.__deinit__` puts an outcome back. `settle` can report twice, or not at all. | A lock over `outcome`, `done`, and `released`, such as the `_Cell` lock, or an atomic state word with release/acquire publication of the outcome. `settle` must decide under that lock, so that exactly one thread reports. S5 moves owner draining into records, so the child count joins this state. |
| `_Inbox` (fibers) | `pending`, `free`, and `size`, shared by the host and every run loop it hosts through `ArcPointer`; no lock. | Fibers on different workers call `_spawn_into` at once. | Removed by S5: a started fiber is pushed to a scheduler queue. A spawn path that remains must be per-worker or locked. |
| `_Fibers` table and `_FiberEntry` | Owned by the host's run loop; confined. | Replaced by scheduled tasks (Pass 13 design item 1). | Owner draining through atomic child counts in records, as designed. |
| `_SupervisorState` and `_Stop` (`src/fp/effects/_async/supervisor.mojo`) | Plain `children`, `stopping`, and `requested` behind `ArcPointer`; confined. | `supervise` runs in any fiber holding a copy, release in another; `_Stop.requested` is read by the parked fiber. **Data race.** | A lock over the state, with `stopping` checked under it, so that a start racing a release is either admitted and drained or aborts. `requested` set under a lock or atomically before `signal.notify`. |
| `Fiber` handles (async) | Hold the record. | Transferable once the record is synchronized. | Nothing more. |
| Synchronous `Fiber` and `_FiberState` (`src/fp/effects/fibers.mojo`) | Already cross-thread: `done` is atomic, and only the worker touches `program` and `result` before the join. | Unchanged. | Nothing; S1 extracts the thread owner. |

### Wake registry, signals, and timers

| Owner | Today | Under parallel execution | Needs |
|---|---|---|---|
| `Signal` (`_EventState`, `src/fp/_internal/waking.mojo`) | Revision and subscriber list behind the `_Cell` spin lock; `notify` copies the wakers and wakes them outside the lock. The docstring disclaims cross-thread use. | Notified from workers and foreign threads; fibers subscribe on other workers. | Qualification (S3): ordering, wake before park, and teardown. The structure already has the right shape; the docstring changes once it is qualified. |
| `_Subscription` | Retires its entry under the signal's lock; aborts on double retirement. | Dropped on any worker. | Nothing beyond `Signal`'s qualification. |
| `_Runtime` and `_ReadyState` (`waking.mojo`) | One tree of generation-checked nodes and the root's timer heap behind one `_Cell` lock. | Every wake and timer for every fiber would contend for one lock. | Pass 13 design items 1 and 4: a registry per fiber and a timer heap per worker, keeping the generation checks. The root wake hook must run outside the lock, as `Signal.notify` already wakes outside its own. |
| `_Waker` | Copies the runtime handle, ticket, and epoch; `wake` takes the registry lock and checks the generation. | Called from any thread. | Unchanged; the epoch check already rejects stale wakes. |
| `_Clock` and `Clock` (`waking.mojo`, `src/fp/effects/_async/host.mojo`) | The system clock reads `monotonic()`. A manual clock is an `Instant` behind the cell lock. | Read from every worker. | Nothing for the system clock. Under `TestControl` the manual clock is advanced by the controlling thread while workers read it; that profile stays current-thread. |

### Cells and coordination

| Owner | Today | Under parallel execution | Needs |
|---|---|---|---|
| `_Cell`, `_Guard`, `_try_lock`, `_lock_metadata` (`src/fp/_internal/cells.mojo`) | A one-byte spin lock: compare-exchange to acquire, store to release, both sequentially consistent. `_lock_metadata` spins with `sleep(0.0)`. | Correct as a mutex: acquisition and release order the guarded state. Spinning wastes a worker under contention; `sleep(0.0)` is a yield. | Nothing for correctness. 13a should measure contention, and use acquire/release orderings once they are justified, with the orderings documented (design item 8). |
| `_lock` (`src/fp/effects/coordination.mojo`) | Spins with `sleep(0.001)` until acquired or canceled. Used by the synchronous family, `Permit.__deinit__`, and `Completion.complete`. | A worker that runs a `Permit` destructor, or completes a `Completion` while contended, blocks for at least 1 ms. | `Completion.complete` from a foreign thread can keep it. Destructors on workers should not sleep: a permit release on a worker could use the bounded `_try_lock` path with a fallback, or keep the lock section short enough that sleeps are rare. Measure under 13c. |
| `Ref`, `Deferred`, `Queue`, `Semaphore`, and `Permit` (`coordination.mojo`, `src/fp/effects/_async/coordination.mojo`, the engine's `Ref` and `Deferred`) | One `_Cell` per owner plus a `Signal`. Async attempts take `_try_lock` and return a runnable `Wait()` when it is held (`_attempt` in `_async/attempts.mojo`). User callbacks and replaced-state destructors run under the lock. | Qualified under contention from OS threads for the synchronous family (`test_coordination`). In the async family, a fiber that finds the lock held is rescheduled immediately, so a long callback under the lock makes other workers busy-poll. `Deferred.get` copies the value, so copies of a `T` holding an `ArcPointer` are shared. | Run the async coordination clients under the work-stealing profile (13c gate). Consider waiting on the owner's signal instead of rescheduling after a failed `_try_lock`, which needs a notification on unlock. The contract states that callbacks under the lock must be short. |
| `_ExclusiveCell` (`src/fp/_internal/exclusive.mojo`, iteration branching) | An atomic gate that aborts on overlapping access. | Unchanged: it already detects concurrent use and aborts rather than racing. | Nothing. |

### Callbacks, cancellation, and accounting

| Owner | Today | Under parallel execution | Needs |
|---|---|---|---|
| `Completion` and `_CompletionState` (`src/fp/effects/_async/callbacks.mojo`) | Outcome and `closed` behind the `_Cell` lock; `complete` stores under the lock, notifies after unlocking, and destroys a rejected payload on the calling thread. | Completed from foreign and blocking threads; the waiting fiber takes the outcome on any worker. | S3 qualification. The payload rule belongs in the contract: the outcome moves to the waiting fiber's worker, and a rejected one is destroyed on the completing thread. |
| `Callback.counted` and `_Budget` (`src/fp/effects/_io_core.mojo`) | `_Budget` holds plain counters (`remaining`, `consumed`, `registrations`) and the reporter, shared through `ArcPointer` by every run loop of a root; documented as confined. `Callback.__deinit__` decrements `registrations`. | **Data race.** Run loops on different workers draw from `remaining`; a `Callback` dropped on any worker decrements `registrations`. | Per Pass 13 design item 3: the transition budget becomes per worker. `registrations`, which tells the root whether external work is pending, must be atomic or move to the runtime, which increments and decrements it with release/acquire. `report` and `reporter` are read-only after construction and can be shared. |
| `CancellationToken` (`_io_core.mojo`) | An atomic flag set by compare-exchange, then a `Signal` notification. | Canceled from any thread. | S3 qualification only. |
| `IOContext` (`_io_core.mojo`) | Copied per run loop; `_region` is an `ArcPointer[Int]` compared by address only. | Moves with its run loop. | Nothing; `_region` is never mutated. |
| `_Reporter` and `IORuntimeConfig.reporter` (`src/fp/effects/_async/kernel.mojo`) | A thin function called by `_FiberRecord.settle`; the default prints to `stderr`. | Called from whichever worker settles a record, possibly from two workers at once. | The guide states that a reporter must be callable from any thread, concurrently. Printing to `stderr` is safe, though lines from two reporters may interleave. |
| `Driver`, `TestControl`, `_Driver` (`host.mojo`, `kernel.mojo`) | Confined to the polling thread; `Driver` is linear. | `Driver` embeds the current-thread profile only (Pass 13 decision 3). | Pass 12's host notifier, called from any thread; the host asserts that it is thread-safe. |

### Elsewhere in the library

| Owner | Today | Under parallel execution | Needs |
|---|---|---|---|
| `Node` (`src/fp/adt/data.mojo`) | Immutable data behind `ArcPointer`. The destructor releases children in a loop when `count() == 1`. | Immutable sharing is safe. A relaxed `count() == 1` followed by moving children out needs an acquire fence to see other threads' last uses, as Rust's `Arc::get_mut` does. When the last two owners drop at once on two threads, both can see a count of 2, and the final release falls back to recursive destruction, which can overflow the stack on deep values. | An acquire fence after the uniqueness check. Recursive destruction under concurrent drops is a stack-safety issue to document or fix, not a race. |
| `Resource` and the finalization scopes | Hold the program's acquired value and finalizers as payloads. | Transferable when their payloads are. | Covered by the payload contract. |

The three data races marked above (`_FiberRecord`, `_SupervisorState`, and
`_Budget`) are all owned by S5's engine refactor or by Pass 13's per-worker
budget; none is reachable on today's runtime.

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

The library should therefore treat a future `Send`/`Sync` as likely but
unscheduled. Pass 13's commitment to adopt them if Mojo adds them stands, and
whatever the library adopts now should be replaceable by them.

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
   specific to Mojo executables in this environment. Design item 8's sanitizer
   run needs another host or a fix, and remains open.

So Mojo 1.2 cannot prove that a payload is transferable. It can find the two
most common hazards, raw pointers and `ArcPointer`, in user-defined structs and
in `List` and `Optional`, with known holes and false positives.

## Recommendations

1. **Adopt the contract** above in the async guide and the scheduler page
   before the work-stealing profile becomes the default (Pass 13 decision 1),
   with the `ArcPointer` race and the current-thread profile shown prominently.
   Pass 12's matrix gains a row: payloads stored in `IO`, fiber state, and
   coordination owners are transferable, and shared ones are shareable.
2. **Fix the three races before 13c,** as part of S5: `_FiberRecord`'s outcome
   and release state, `_SupervisorState` and `_Stop`, and `_Budget.registrations`.
   Fix `Node`'s uniqueness fence independently. Each fix needs a multi-thread
   stress client in 13e (`wstp_ownership` covers the first two).
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

## Open questions for the integrator

1. Is the opt-in marker (recommendation 3) a public API change the user
   approves, and under which name and module?
2. Does the raw-pointer rejection apply to the synchronous family as well,
   since `_Erased` is shared, or only to async constructors? One owner suggests
   both, which is also a behavior change for synchronous code.
3. Should a fiber that finds a coordination lock held wait on the owner's
   signal instead of being rescheduled at once? It changes `_attempt` and adds
   a notification on unlock.
4. Where can the thread sanitizer run? Design item 8 assumes one, and it does
   not run for Mojo executables in this container.
