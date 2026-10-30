# Async composition

The canonical `fp.effects._async` owners implement typed sequencing, fixed-state
iteration, and structured child groups in pure Mojo. Application recipes select
`Async[E]` through the public family and Pipeline interfaces. The
[state-machine contract](async-state-machines.md) defines entered ownership;
[callbacks](async-callbacks.md) add external completion with owned withdrawal.

## Interfaces and ownership

| Interface | Behavior |
|---|---|
| `pure[E](value)` | Own a value in a deferred machine with the selected exact error type |
| Pipeline `flat_map(next)` | Move a successful value into a one-shot continuation that constructs the next machine |
| `tail_rec_m[Async[E]](step, initial)` | Repeatedly move state through a fixed machine type returning `ControlFlow[Result, State]` |
| `both(left, right)` | Run a typed child pair and return its ordered success tuple after both finish |
| `scoped_both(left, right)` | Run scoped children with a fresh resource borrow for every child poll |

The public surface is `fp.effects.async_runtime`; the implementation layout
under `src/fp/effects/_async` is:

- `kernel.mojo`: waits, shared private execution slots, linear roots and drivers.
- `composition.mojo`: sequencing, iteration and their callable adapters.
- `children.mojo`: shared pair lifecycle, ordinary and scoped invocation boundaries.
- `scopes.mojo`: the existing resumable acquisition/use/cleanup coordinator.

The public `Driver` and internal `Task` are non-Deinitable. They own the complete
entered computation tree and can finish only after that tree completes. Internal
`_Slot` storage is shared by roots, bind nodes, loops, and child groups. An entered
slot aborts if destroyed before completion; unopened recipes can be discarded. This guard
detects interpreter misuse but cannot asynchronously finalize an abandoned slot.
Raw machine polling still requires compliance with the protocol.

Each slot owns its machine through the native `OwnedPointer[P]`. The exact `P`,
including captured origins, remains in the type. There is no erased pointer,
unsafe origin conversion, or reference to a movable parent frame. This adds an
allocation per slot, including each constructed loop iteration; only one
iteration's running storage is retained at a time. It is a correctness-oriented
representation, not an allocation-free performance claim.

## Sequencing and loops

Continuation and loop factory invocation delegate to the existing callable
receiver dispatch and error capture. Factories are bounded synchronous
constructors of deferred work. Acquisition requiring asynchronous cleanup belongs
in an entered resource scope, not in a factory that may return an unopened
machine. Source failure or cancellation skips the continuation. A separate
handoff step checks cancellation before moving the source value into it. A
successfully constructed next machine is installed before its next entry
checkpoint; cancellation discards it only if it has not entered.

Loop factories must support repeated invocation. `Continue` transfers the next
state, `Break` transfers the final result, and failure or cancellation prevents
another iteration. The current step completes its entered cleanup before the
loop finishes. Iteration does not grow a recursive continuation chain.

Each node performs at most one factory invocation or one active-child poll per
outer poll. Explicit runnable transitions separate stages. Nested groups rotate
among ready children; this is hierarchical cooperative progress, not preemption
or equal scheduling weight for every leaf in an arbitrarily shaped tree.

Static bind type depth and runtime iteration count remain distinct limits. The
qualification includes a 64-bind type tree and one million loop iterations,
with separate execution under a 1024 KiB stack limit. These fixtures do not
establish arbitrary-depth heterogeneous sequencing or bounded user payload size.

## Child lifecycle and wake conditions

Children start unmasked with separate cancellation tokens. The parent's mask
controls observation and forwarding of its own request. A terminal unsuccessful
child requests cancellation of unfinished siblings. An already completed child
is never polled or canceled again; an unopened sibling is discarded. Every
entered child is drained through its cleanup before the group can complete.

On the scheduled path, slots own child registrations and select ready children
through FIFO metadata. Parked children are not scanned. Wait descriptors retain
signal revisions, deadlines and cancellation conditions for the direct-poll
protocol. Once a parent request is forwarded, its sticky flag does not repeatedly
wake masked child cleanup. See the [scheduler](async-scheduler.md) for details.

Failures preserve exact error payloads in declaration order, with each child's
existing body/finalizer order intact. Failure dominates cancellation alone.
The canceled flag records parent observation or a child's canceled outcome,
including sibling-induced cancellation. Two successful children return their
ordered tuple. `_zip_outcomes` retains that tuple and delegates every unsuccessful
combination to canonical `_finish`; it does not implement another error merger.

Failure retagging uses canonical `fp.effects.outcomes._failure_as`; scope and
finalization adapters share those outcome mechanisms.

Scoped children borrow the outer owner only within each poll. External captures
and independent borrowed results retain their native origins. Nested child
cleanup must finish before outer release starts, and the resource remains alive
through any suspension of that release.

## Qualification and limits

The maintained composition, loop lifecycle, child and origin clients cover
move-only state/errors, construction failure, cancellation checkpoints, child
terminal-state combinations, independent external origins, unopened siblings,
parent masking, wake-before-park races, mixed waits, and nested resource cleanup.
Loop probes assert at most one live step and exactly-once state destruction.
Long-loop and static-depth clients also execute under a recorded stack limit.

```sh
pixi run python experiments/async-state-machines/qualify.py \
  --output .cache/async-composition-check --jobs 2 \
  --client composition --client loop_lifecycle --client children --client depth
```

Each output directory must be fresh. The runner retains source/package O0/O3
results, raw diagnostics, executable hashes and independent audits. Sustained
loop storage and local sequencing costs are recorded in the
[overnight results](async-qualification.md#overnight-results).

This representation supports finite statically typed task trees and runtime
iteration. It does not promise arbitrary concrete bind depth, allocation-free
steps, or bounded user payload sizes. A noncooperating poll blocks its host;
nonterminating masked cleanup prevents completion.
