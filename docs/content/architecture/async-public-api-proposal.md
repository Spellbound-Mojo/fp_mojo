# Proposed public async API

This proposal defines a first public surface for the pure-Mojo runtime already
implemented under `experiments/async-state-machines/`. It follows the
[readiness review](async-public-api-review.md). **Status: proposed for review;
the imports and additions below are not available public APIs yet.** This page
changes no runtime behavior or exports.

The recommended contract is cooperative execution on one host thread, concrete
owned machine types, exact typed outcomes, and structured cleanup. Cats and Cats
Effect inform sequencing, resources, and cancellation; native Mojo ownership and
origins determine the representation. Long-running stress and performance work
is deferred to a later overnight pass. It is not needed to discuss this design.

## Namespace and supported boundaries

Use `fp.effects.async_runtime` for application construction and host execution.
Use `fp.effects.async_runtime.protocols` for implementing custom leaf machines
and scoped bodies. Both are documented import paths. Other submodules are
implementation details. Examples should qualify the application module as `ar`
when synchronous operations are also in scope.

Keep canonical `Outcome`, `EffectFailure`, `ExitCase`, `CancellationToken`, and
`Permit` in `fp.effects`; `ControlFlow`, `Continue`, `Break`, `Left`, and `Right`
remain in `fp.data`. Async operations use these exact types. Do not introduce a
second outcome representation or re-export conflicting async names from
`fp.effects` itself.

The first surface has three boundaries:

| Boundary | Supported names | Purpose |
|---|---|---|
| Application | Constructors and coordination handles listed below; `RaceResult`, `Poll` | Build unopened, concretely typed work |
| Host | `Driver`, `Progress`, `Clock`, `run` | Own execution, deliver events, observe deadlines, and drain shutdown |
| Extension, from `.protocols` | `Machine`, `ScopedMachine`, `CleanupMachine`, `Step`, `Wait`, `Signal`, `Context` | Implement cooperative leaf operations and bodies with per-poll loans |

`Context[E]` is a public alias of canonical `IOContext[E]`. Add `now() -> Int`
to that canonical context so extensions can read the inherited clock without
accessing `_clock`. The existing `canceled()` and `request_cancel()` retain
their meanings. Tokens, mask markers, parent registrations, slots, subscriptions,
locks, and scheduler storage stay outside the extension contract.

Raw `Task`, `run_pair`, detached start/join handles, cross-thread callback delivery,
OS readiness registration, and custom child schedulers are outside this first
surface. `Driver` is the single application root owner. Library combinators own
child execution; custom leaf machines do not manually poll nested recipes.

## Recipe and callable contract

In the tables, `M[T, E]` means any concrete `Machine` with `Value == T` and
`Error == E`. It is signature notation, not a proposed erased type or a Mojo
declaration. `T`, `E`, state, and callback types retain their native origins.

Constructors consume recipe and callback arguments. Construction invokes no
user callback. `pure` owns an already evaluated value; `delay` postpones the
callback that produces it. Unopened recipes can be discarded. Once driven,
the root owner must remain alive until execution and cleanup finish. Recipes
are consumed for one execution; repeating work constructs another recipe.

Select `E` explicitly for leaf operations such as `pure[E]`, `delay[E]`, and
`sleep[E]`; composites infer it. A continuation's machine must have exactly the
source error type. A native callback can raise that `E` or `Never`; there is no
implicit error union or conversion to `Error`. Multiple error kinds require a
caller-selected native sum type shared by the computation.

Ordinary native functions, stored thin functions, closures, and library callables
should be admitted through the existing callable adapters and invocation owners.
One-shot continuations can consume captures. Loop factories must be repeatable
and cannot consume their captures once per iteration. Admission borrows end at
construction; independently borrowed captures must outlive execution. This native
callback convenience is an addition to the experiment's protocol-callable entry
points and needs focused qualification before publication.

## Construction and sequencing

| Proposed call shape | Result | Contract and implementation owner |
|---|---|---|
| `pure[E](value: T)` | `M[T, E]` | Move the value into the existing `Pure` recipe |
| `delay[E](thunk)` | `M[thunk.Out, E]` | New adapter; defer one synchronous callback, using canonical IO delay and execution |
| `eval_io(program)` | `M[program.Value, IOContract[program].Error]` | New bridge; consume a compatible synchronous IO recipe in one poll, using the current context |
| `map(program: M[A, E], function)` | `M[B, E]` | New derived operation; move the success into the callback and capture its compatible error through existing sequencing |
| `bind(program: M[A, E], next)` | `M[B, E]` | Existing sequencing; invoke `next` once after success to obtain `M[B, E]` |
| `loop(initial: S, step)` | `M[B, E]` | Existing iteration; each call consumes `S` and returns the same concrete machine type yielding `ControlFlow[B, S]` |
| `sleep[E](nanoseconds: Int)` | `M[NoneType, E]` | New function spelling over existing `Sleep[E]`; deadline starts on entry |

Use `bind(program, next)` as the initial value-first sequencing spelling. It
matches the experiment and avoids introducing another `flat_map` calling
convention beside the existing algebra API. `Continue[S]` moves the next state;
`Break[B]` moves the final value. Looping retains one current step and yields
between iterations; it does not grow a recursive recipe chain at runtime.

`delay` and `eval_io` are synchronous inside their poll. They do not make blocking
IO asynchronous, offload it to a thread, or preempt a long callback. Use them for
short work and use `callback` for externally completed operations. The IO bridge
must invoke the canonical runner with the current context, preserving its clock,
mask, token, and scheduler ancestry; calling top-level `run_io` with a fresh
context would violate this contract.

Construction has no native callback error. Callback failures enter the canonical
`Outcome` during execution. The new `map` adapter delegates to the existing bind
and callable mechanisms; it does not add a second execution state machine.

## Structured concurrency and timeouts

| Proposed call shape | Successful value | Terminal policy |
|---|---|---|
| `both(left: M[A, E], right: M[B, E])` | `Tuple[A, B]` | Both succeed, or failure/cancellation requests sibling cancellation and drains both |
| `race(left: M[A, E], right: M[B, E])` | `RaceResult[A, B]` | First observed terminal selects the result; cancel and drain the loser before returning |
| `timeout_to(program: M[T, E], nanoseconds, fallback: M[T, E])` | `T` | Start the deadline on wrapper entry; timer victory requests cancellation; admit fallback only after successful draining |
| `Nursery[P](limit)` | Its recipe yields `List[P.Value]` | Own at most `limit` total accepted children of one exact machine type |

`RaceResult[A, B]` remains the canonical `Choice` with `Left[A]` and `Right[B]`.
Equal arm types remain distinguishable. A selected error or cancellation also
wins: this API promises first terminal observation, not first success. Initial
ties favor the left child; later selection follows scheduler readiness order.
Losing cancellation is normalized, losing errors remain observable, and a parent
cancellation is settled independently. There is no timestamp arbitration.

A timeout is a cancellation deadline. Masked work and finalizers can extend
the time before return indefinitely. Cleanup failure prevents fallback; parent
cancellation skips it. A zero-duration timeout keeps the same observation rule,
so an immediately terminal left program can win.

`Nursery[P].spawner()` returns a copyable `Spawner[P]`. Its immediate
`try_spawn(child)` consumes the recipe and returns `None` on acceptance or the
original unopened recipe on rejection. `close()` is idempotent and ends admission;
normal closure lets accepted children finish. Failure or cancellation closes
admission and cancels unfinished children. Completion collects values and errors
in admission order. The host must arrange closure for a normally finishing nursery.

The limit covers queued, active, and completed children for the nursery's whole
execution. It is not replenished when a child finishes. An unlimited service can
use a fixed number of looping workers and a bounded queue. Heterogeneous admission
requires an explicit common native representation. Retained spawners reject work
after closure or nursery destruction and never own detached running tasks.

## Resources and finalization

| Proposed call shape | Contract |
|---|---|
| `scope(acquire, use, release)` | New function spelling over `Scope`; acquire `R`, lend `R` to a `ScopedMachine` per poll, then release through `CleanupMachine` |
| `scoped_both(left, right)` | Existing scoped pair; each child receives the same resource through a fresh immutable loan |
| `guarantee(program, cleanup)` | Run owned cleanup after entry on every terminal path; discard its successful value |
| `guarantee_case(program, cleanup)` | Cleanup is a `ScopedMachine` borrowing exact `ExitCase[E]` for each poll |
| `on_cancel(program, cleanup)` | Run cleanup when the body exit records cancellation, including failure plus cancellation |
| `uncancelable(program)` | Execute under a fresh lexical mask |
| `uncancelable_with[E](factory)` | Consume a once-callable factory taking `Poll[E]` and returning a machine with exact `E` |
| `poll.apply(program)` | Restore the cancellation state preceding that Poll's active lexical region |

All error types match exactly. Scope acquisition and cleanup are masked. A
failed acquisition does not release a nonexistent resource. Once acquisition
succeeds, cleanup runs even if cancellation skips the body's first poll. Scope
keeps the resource and any completed body value alive through suspended cleanup.
A partially acquiring operation must own and clean up its own partial state.

The guarantee constructors install their protection before body execution;
cancellation after that entry still finalizes. An entirely unopened recipe
executes no finalizer. Resource and exit loans use immutable origins and end when
each poll returns. Neither stored state nor results can retain those fresh loans;
independent external captures and returned origins remain valid. There is no
mutable-scoped contract in this proposal.

`Poll` is copyable but restores only its matching current region. It cannot
pierce a newer mask, a finalizer's mask, or another child's independent region.
An escaped handle is inert outside its region. It preserves current task metadata
when restoring cancellation state. Children start with independent, initially
unmasked tokens; the parent's mask controls when its request reaches them.

These constructors continue sharing Scope, canonical exit/error accumulation,
and mask restoration. A separate reusable async `Resource` builder is later work;
this first interface makes the existing scoped borrowing boundary explicit.

## Callbacks and coordination

`callback(register, withdrawal)` returns `M[T, E]`. Registration is a synchronous
once-callable accepting `Completion[T, E]` and returning `NoneType`; it can raise
`E` or `Never`. The already-owned withdrawal machine has value `NoneType` and
exact error `E`. Registration can retain a copy of the completion handle.

`Completion.complete(outcome: Outcome[T, E]) -> Bool` consumes the supplied outcome.
The first accepted terminal decision closes the cell. Later calls return `False`
and destroy their input, including after task completion. Copies preserve native
origins; shared metadata ownership does not extend an external borrow's validity.
Withdrawal runs after every entered registration, including partial registration
failure and immediate completion, and can suspend under a mask. Calls to completion
and submission handles belong to the same host thread in this initial contract.

Coordination handles are copyable shared owners; their methods below return
unopened machines, not immediate values:

| Handle | Methods and successful values |
|---|---|
| `Deferred[T]`, with copyable `T` | `complete[E](value) -> Bool`; `try_get[E]() -> Optional[T]`; `get[E]() -> T` |
| `Queue[T](capacity)`, with movable `T` | `size[E]() -> Int`; `try_offer[E](value) -> Optional[T]`; `offer[E](value) -> NoneType`; `try_take[E]() -> Optional[T]`; `take[E]() -> T` |
| `Semaphore(permits)` | `available[E]() -> Int`; `acquire[E]() -> Permit`; `with_permit(program) -> program.Value` with the program's error type |

`Deferred.complete` reports whether assignment won. Readers receive copies.
Queue values are FIFO. A successful `try_offer` returns `None`; rejection returns
the original value. Waiting `offer` owns its value until enqueued or canceled.
The `try_` operations do not wait for capacity or an item, but can yield on guard
contention. No FIFO ordering among waiting producers, consumers, or permit
acquirers is promised.

Cancellation does not roll back committed queue operations or callback side
effects. A removed value whose success is suppressed by late cancellation is
destroyed. `with_permit` acquires cancelably and retains the canonical owned
permit through body cleanup. Permits are returned through that existing owner.
These methods keep using the synchronous library's shared state transitions.

## Host contract and shutdown

`Driver(program)` creates a fresh token and monotonic clock.
`Driver(program, token, clock)` copies the supplied shared handles. Both consume
the unopened program into a movable, non-Deinitable root. The supported members
are `poll(budget)`, `cancel()`, and consuming `finish()`; internal task/context
fields are not public extension points.

| `Progress` field | Meaning |
|---|---|
| `completed: Bool` | The entire subtree, including cleanup, is terminal |
| `runnable: Bool` | More work can be attempted immediately, including a due timer |
| `deadline: Optional[Int]` | Earliest live deadline in the supplied clock's nanoseconds |
| `polls: Int` | Root polls performed by this call |
| `timers: Int` | Timer events processed by this call |

`poll(budget)` performs at most `budget` root polls plus timer events. A root
poll can invoke nested operations; this is not a bound on all child polls,
instructions, wall time, destructor work, wake fanout, or heap maintenance.
Budget zero observes status without making progress. The driver itself performs
no host idle sleep. Callbacks and custom polls must cooperate by returning.

The host delivers available events, calls `poll`, and uses `runnable` and
`deadline` to choose its next call. When idle, the host arranges another call
after event delivery or the reported deadline. The runtime does not install an
OS event source or a host wake hook. If no source can complete parked work, the
host must request cancellation and continue draining.

`cancel()` requests cancellation; it does not join. Continue polling until
`completed`, then call `finish()` exactly once to obtain
`Outcome[P.Value, P.Error]`. `finish()` before completion is a contract violation.
There is no abandon or detach operation, and automatic destruction cannot run
asynchronous cleanup. An uncooperative poll or nonterminating masked cleanup can
prevent shutdown. Moving a driver preserves all these obligations.

`run(program)` and `run(program, token)` are blocking convenience runners for
self-contained work. They use the same Driver with the existing 1 ms idle-sleep
fallback. Host-delivered callbacks normally use Driver directly.

`Clock()` reads monotonic nanoseconds. `Clock.manual(now=0)` creates shared
deterministic time; `advance_to(now)` only advances a manual clock. Absolute
deadlines use that clock's origin and are not wall-clock timestamps.

## Outcomes, invalid inputs, and extension rules

The terminal shape stays `Optional[Result[T, EffectFailure[E]]]`: outer absence
means cancellation, `Ok` means success, and `Err` holds a nonempty ordered error
collection plus an independent cancellation flag. Failure can coexist with
cancellation. Errors are never discarded merely because cancellation arrived.

| Composition | Error order |
|---|---|
| Scope / guarantee | Body, then inner-to-outer cleanup |
| Both | Left subtree, then right subtree |
| Nursery | Admission order, retaining each child's internal order |
| Race | Selected subtree, then losing subtree; normalize losing cancellation only |
| Callback | Completion error, registration error, withdrawal error |

This first proposal preserves existing input-validation behavior explicitly:
Queue requires positive capacity and Semaphore requires nonnegative permits;
invalid construction raises ordinary native `Error` before execution. Driver
budgets and nursery limits must be nonnegative. Sleep/timeout durations must
lie in `0..10^18` nanoseconds, and the entry-time absolute deadline must fit in
`Int`. Manual time is nonnegative and cannot move backward. Violating those
latter preconditions, or consuming unfinished execution, aborts as in the
experiment; it does not fabricate an error of arbitrary `E`. Applications must
validate external configuration before invoking these APIs. Checked configuration
constructors would be a separate, explicit API change.

The extension protocol keeps `Machine.Value`, `Machine.Error`, and
`poll(mut self, Context[Error]) -> Step[Value, Error]`. A custom machine returns
`Step.pending(wait)` to suspend or `Step.ready(outcome)` exactly once to finish.
It is never polled after completion and must release its own entered resources
before reporting terminal state. Direct application polling is outside the
supported execution contract; Driver and the library's child owners perform it.

Supported waits are `Wait()` for a scheduling yield, `Wait.never()` for no ordinary
wake source, `Wait.changed(signal, revision)`, and `Wait.until(deadline)`.
Cancellation remains a wake source when the context permits observation.
`Signal` exposes construction, `revision()`, and `notify()` only. Read the revision
before inspecting the associated state, then return the captured revision if
still waiting; registration rechecks it to preserve notifications before parking.
Wait fields, flattened child waits, subscriptions, and readiness evaluation stay
internal. Masked cleanup can use ordinary waits without manipulating mask fields.

`ScopedMachine` additionally receives its declared `Input` through a fresh
immutable reference each poll. `CleanupMachine` receives that loan and the exact
exit, and yields `NoneType`. Generic wrappers preserve the exact inputs, results,
errors, callable receivers, and origins. Supporting these traits does not promise
safety for implementations that violate their protocol.

## Naming concrete return types

Application code normally infers recipe types. Typed continuation factories and
generic wrappers still need public ways to name them. Retain the existing logical
names `Pure`, `Bind`, `Loop`, `Both`, `ScopedBoth`, `Scope`, `Callback`, `Race`,
`Timeout`, `Sleep`, and `Masked`; add `Delay`, `EvalIO`, and `Map` for the new
adapters. Only their documented type parameters, `Value`/`Error`, and protocol
conformance are supported, not fields or storage layout.

For ordinary finalization, publish `Guarantee[P, Q]`, `OnCancel[P, Q]`, and
`GuaranteeCase[P, F]` as aliases over the existing scope adapters. This deliberately
changes the experimental `Guarantee` spelling, which currently takes an already
adapted scoped finalizer. Callers must not name private `_ProgramUse` types.
Keep `Poll[E].Applied[P]` as the public result alias of `apply`.

Add associated result aliases to handle types: `Deferred[T].Complete[E]`,
`TryGet[E]`, and `Get[E]`; `Queue[T].Size[E]`, `TryOffer[E]`, `Offer[E]`,
`TryTake[E]`, and `Take[E]`; `Semaphore.Available[E]`, `Acquire[E]`, and
`WithPermit[P]`. These name the existing native recipe types and introduce no
new state, allocation, or interpreter. Callable recipe aliases use the admitted
protocol callable type. The exact return type of a native entry point can also
be named with `type_of` on its public construction expression; clients must not
spell private native adapters. Generic forwarding is part of the focused
acceptance tests, not a reason to erase callback or result types.

## Relationship to Pipeline and supported release

This first interface composes through its typed constructors. It does not yet
declare an `Async[E]` Functor/Monad instance or promise that `pipeline(machine)`
selects async semantics. Existing Pipeline selection can treat an undeclared
carrier as a plain value; the async documentation must not suggest otherwise.
Do not add a separate fluent wrapper with its own sequencing implementation.

A subsequent `Async[E]` design should reuse the existing family and Pipeline
machinery, including admitted callbacks, generic result metadata, and deferred
error capture. That requires focused native-signature and algebra-law work.
Async stored-error recovery also needs an explicit policy for accumulated failures
and cancellation. Neither family integration nor recovery is implicitly promised
by promoting the lower-level runtime surface.

Publication should initially be an opt-in API preview, qualified for the pinned
Mojo 1.2 Linux x86-64 environment and cooperative host-thread use. Source contracts,
supported type aliases, and error/cancellation behavior are versioned; compiler
ABI, concrete layout, allocation counts, and compilation complexity are not
compatibility promises. Preview breaking changes require explicit migration notes.
The supported-release decision follows the deferred long-running qualification;
this proposal does not turn the previous correctness matrix into stress or
performance evidence.

## Implementation passes after agreement

1. **Module and host boundary.** Move the runtime to its canonical production
   owner, expose the selected namespaces and logical recipe types, hide raw Task
   and scheduler internals, and add canonical context clock access. Any temporary
   experimental import path forwards to that owner instead of keeping a copy.
2. **Application adapters and typed metadata.** Add `eval_io`, `delay`, derived
   `map`, `sleep`/`scope` spellings, native callback admission, and the finalization
   and handle aliases. Preserve existing scheduling, lifecycle, and error policy.
3. **Public-client qualification and documentation.** Add short runnable examples
   for typed sequencing, callback timeout, scoped cleanup, and host cancellation.
   Verify ordinary and generic clients without private imports, move-only values,
   external origins, and rejection diagnostics through source/package O0/O3.
   Extend export/provider tooling to understand the nested public namespaces;
   update inventories, compatibility records, and installation/import guidance.
4. **Deferred overnight qualification.** Exercise sustained reuse, cancellation,
   callback/timer retirement, and bounded retained storage; measure performance
   separately. Agree the run window and budgets when scheduling this work.

All implementation passes stay in pure Mojo and integrate through shared
`nightly`. This proposal pass runs only documentation validation. Acceptance of
the proposal precedes public exports or runtime implementation changes.
