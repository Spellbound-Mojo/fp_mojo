# Async composition implementation

The [composition plan](async-composition-plan.md) is implemented in the private
`experiments/async-state-machines/` package. It extends the
[initial foundation](async-state-machines.md) with typed sequencing, fixed-type
iteration, and nested structured child pairs. Runtime code is pure Mojo; it
uses no coroutine intrinsics or native context-switch backend.

This records the composition milestone. The subsequent
[callback registration pass](async-callbacks.md) adds typed external completion
and owned withdrawal.

## Interfaces and ownership

| Interface | Behavior |
|---|---|
| `pure[E](value)` | Own a value in a deferred machine with the selected exact error type |
| `bind(program, next)` | Move a successful value into a one-shot continuation that constructs the next machine |
| `loop(initial, step)` | Repeatedly move state through a fixed machine type returning `ControlFlow[Result, State]` |
| `both(left, right)` | Run a typed child pair and return its ordered success tuple after both finish |
| `scoped_both(left, right)` | Run scoped children with a fresh resource borrow for every child poll |

These names are experimental exports only. Existing synchronous IO APIs and
their execution model are unchanged. The source layout is:

- `kernel.mojo`: waits, shared private execution slots, linear roots and drivers.
- `composition.mojo`: sequencing, iteration and their callable adapters.
- `children.mojo`: shared pair lifecycle, ordinary and scoped invocation boundaries.
- `scopes.mojo`: the existing resumable acquisition/use/cleanup coordinator.

`Task` remains non-Deinitable. It owns the complete entered computation tree and
can finish only after that tree completes. Internal `_Slot` storage is shared
by roots, bind nodes, loops, and child groups. An entered slot aborts if it is
destroyed before completion; unopened recipes can be discarded. This guard
detects interpreter misuse but cannot asynchronously finalize an abandoned slot.
Raw machine polling still requires compliance with the protocol.

Each slot owns its machine through the native `OwnedPointer[P]`. The exact `P`,
including captured origins, remains in the type. There is no erased pointer,
unsafe origin conversion, or reference to a movable parent frame. This adds an
allocation per slot, including each constructed loop iteration; only one
iteration's running storage is retained at a time. It is a correctness-oriented
representation, not an allocation-free performance claim.

The initial inline-slot encoding exceeded both 120-second and 300-second build
budgets for 64 nested binds at O0. Typed indirection allowed that same fixture
to compile and run. This is a library representation change; the compiler and
standard library were not modified.

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

`Wait` holds an owned, flattened union of signals, revision snapshots, deadlines,
and cancellation tokens. Each cancellation condition uses its actual child's
token and mask. Once a parent request has been forwarded, that sticky flag no
longer forces repeated polling of parked masked cleanup. The root still uses the
existing 1 ms host idle scan; this is not an OS-backed wakeup implementation.

Failures preserve exact error payloads in declaration order, with each child's
existing body/finalizer order intact. Failure dominates cancellation alone.
The canceled flag records parent observation or a child's canceled outcome,
including sibling-induced cancellation. Two successful children return their
ordered tuple. `_zip_outcomes` retains that tuple and delegates every unsuccessful
combination to canonical `_finish`; it does not implement another error merger.

`_failure_as` now owns failure retagging in `fp.effects.outcomes`; resources keep
their private `_scope_failure` name as an import alias. These are the only
production-source changes in this milestone, and neither adds a public export. Resource and
finalization regression clients are included in the qualification.

Scoped children borrow the outer owner only within each poll. External captures
and independent borrowed results retain their native origins. Nested child
cleanup must finish before outer release starts, and the resource remains alive
through any suspension of that release.

## Qualification

The extended runner declares seven positive experiment clients, ten negative
clients, and five existing resource/finalization regression clients. It checks
O0 and O3 through source and precompiled imports, with warnings treated as
errors. Rejection fixtures are compile-only and require the declared cause.
Crashes, timeouts and unexpected acceptance are failures.

The positive clients cover move-only state and errors, construction failure,
failure/cancellation checkpoints, all 16 child terminal-state combinations in
both observation orders, independent external origins, unopened siblings,
parent masking, wake-before-park races, mixed signal/timer waits, and nested
resource cleanup. A three-child scoped example runs loops and bind in every
child, moves the suspended task, cancels the parent repeatedly, and releases
descendant cleanup out of order while checking deterministic error order.

The original foundation's 64 acquisition/body/cleanup combinations remain in
the suite. Loop lifecycle probes assert at most one live step and exactly-once
state destruction. The long-loop and static-depth clients also execute under
a recorded stack limit, applied to the executable rather than the compiler.

Qualification passed on Linux x86-64 with **Mojo 1.2.0 (2016d0cd)**:
**88/88 matrix checks**, both warning-free package precompilations, and **12/12
additional executions under a 1024 KiB stack limit**. Input stability, raw logs,
executable hashes and the retained artifact manifest passed their audits.

The completed bundle is
`.cache/state-machine-foundation/qualification-composition-2/report.json`.
The earlier `qualification-composition-1` run was interrupted without a final
report and is not counted as completed qualification. No full-repository suite
or performance benchmark was run; the five existing regression clients cover
the affected outcome/resource behavior through all four configurations.

Reproduce from the pinned Mojo 1.2 environment:

```sh
pixi run python experiments/async-state-machines/qualify.py \
  --output .cache/async-composition-check --jobs 4
```

Each output directory must be fresh. Reports retain source snapshots, compiler
and executable output, hashes, bounded-stack results, and independent audits.

## Remaining boundaries

This milestone supports finite statically typed task trees. Dynamic spawning,
escaping child handles, callback registration/withdrawal, OS I/O integration,
general cancellation-mask restoration, a public asynchronous effect family, and
arbitrary-depth bind interpretation remain separate work. A noncooperating poll
blocks the driver; nonterminating masked cleanup prevents completion.
