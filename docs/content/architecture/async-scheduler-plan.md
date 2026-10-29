# Wake-driven scheduler and async coordination

This accepted implementation pass extends the private pure-Mojo runtime. The
existing typed machine, outcome, scoped borrowing and linear root contracts
continue to own execution. Scheduling stores IDs and metadata, never erased
task pointers or erased payloads.

## Scheduling contract

A shared scheduler owns a hierarchy of ready queues. Each execution slot owns a
generation-checked registration under its enclosing slot. Waking a slot queues
it once and propagates readiness to its ancestors. Intrusive links permit O(1)
unlinking when a slot is consumed or retired, avoiding stale ready entries and
searches through parked nursery children. Ready children are selected FIFO.

Signals own revision counters and generation-checked subscriber registries.
Registration rechecks the revision while subscribing; notification snapshots
targets and releases its guard before scheduling them. Slot-owned subscriptions
are removed before rearming or completion. Cancellation uses the same event
mechanism through the existing cancellation token, preserving masking and the
existing observation checkpoints. No parallel cancellation policy is added.

The scheduler uses the standard library binary heap for timer metadata. Wait
replacement invalidates previous timer generations. Stale heap entries are
discarded, and periodic rebuilding bounds their retained storage relative to
live timers. The earliest live deadline is exposed to the host. Queue and timer
bookkeeping never invokes user task code while holding its guard.

A clock carried by execution context is inherited by children and preserved by
masking. Production time uses the monotonic clock. Tests use a shared manual
clock that only advances. The nonblocking driver executes at most its requested
budget of root polls/timer events, then reports completion, runnable work, or
idle with an optional deadline. Budgeting counts scheduling operations, not CPU
instructions inside arbitrary user polls or heap maintenance.

Existing blocking convenience runners delegate to this driver and retain a
clearly identified host-idle fallback until a suitable public Mojo parking
primitive is established. The nonblocking driver itself never sleeps. Direct
legacy polling without a scheduler remains supported by the existing wait
descriptors. Ordinary and scoped invocation continue to share slot policy.

## Async coordination contract

Private async Deferred, bounded Queue and Semaphore adapters reuse canonical
coordination storage, transitions, cancellation settlement, and owned Permit
release. A poll attempts the canonical guard once; contention yields to the
driver rather than blocking it. Waiting for a value, queue space, or a permit
registers a state-change notification and releases the guard.

Deferred is single-assignment and returns copies to readers. Queue transfers
move-only payloads, retains rejected offers while waiting, and preserves already
committed enqueue/dequeue effects across late cancellation. Semaphore returns a
move-only permit whose destruction restores the count exactly once. No FIFO
waiter fairness or cross-thread task execution is promised. Failed queue
attempts must not notify one another into an endless runnable loop.

## Qualification and platform investigation

Deterministic tests cover registration/notification orderings, duplicate wakes,
stale IDs after storage reuse, timer replacement/cancellation, nested clocks,
budget fairness, masked cleanup, and registration/storage bounds. Existing
source/package O0/O3 clients remain regression gates. New coordination tests
cover many waiting readers, full/empty queues, cancellation around mutation,
owned permit release and captured origins.

Public Mojo APIs for parking, synchronization and OS readiness are investigated
separately against the pinned compiler. Any usable primitive is validated with
a bounded probe. Missing APIs are recorded explicitly; this work does not add
a C backend, private coroutine dependency, or compiler/stdlib modifications.
