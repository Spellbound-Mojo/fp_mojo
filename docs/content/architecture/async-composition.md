# Async composition

`IO[T, E]` sequences work through one iterative run loop in
`src/fp/effects/_async/engine.mojo`. Fixed child groups, races, timers, scopes,
callbacks, and coordination waits are typed machines that `IO` runs as leaves.
The [state-machine contract](async-state-machines.md) defines entered ownership;
[callbacks](async-callbacks.md) add external completion with owned withdrawal.
The [advanced plan](async-advanced-plan.md#pass-8a-progress) records how the run
loop was built and measured.

## Interfaces and ownership

| Interface | Behavior |
|---|---|
| `IO[T, E].pure(value)`, `.delay(f)`, `.defer(f)` | Own a value, evaluate a function, or build an `IO` when the program reaches it |
| `io.flat_map(f)`, `.map(f)`, `.handle_error_with(h)` | Append a frame; the callback runs once, when the run loop reaches it |
| `tail_rec_m[Async[E]](initial, step)`, `traverse`, `collect` | Fold on the run loop: each step binds after the previous step's `IO` |
| `io.both(other)` | Run a typed child pair as a leaf and return its ordered success tuple after both finish |
| `IO[T, E].lift(machine)` | Run a custom machine as one leaf |

The public surface is `fp.effects.async_runtime`; the implementation layout
under `src/fp/effects/_async` is:

- `engine.mojo`: `IO`, its `Async[E]` family, and the run loop.
- `kernel.mojo`: waits, shared private execution slots, linear roots and drivers.
- `composition.mojo`: typed sequencing and iteration machines used inside leaves.
- `children.mojo`: shared pair lifecycle, ordinary and scoped invocation boundaries.
- `scopes.mojo` and `resources.mojo`: the resumable acquisition/use/cleanup
  coordinator and the resource plans `Resource` erases.

The public `Driver` and internal `Task` are non-Deinitable. They own the complete
entered computation tree and can finish only after that tree completes. Internal
`_Slot` storage is shared by roots, leaves, and child groups. An entered slot
aborts if destroyed before completion; an unopened `IO` can be discarded. This
guard detects interpreter misuse but cannot asynchronously finalize an abandoned
slot. Raw machine polling still requires compliance with the protocol.

An `IO` is a flat program: one head (a value, a failure, a leaf, a deferred
factory, a mask, or a restore region) and the frames applied after it. Values
and callbacks cross the run loop in private erased boxes. A box is opened only by
a function specialized at the typed call that created it, so `IO` keeps origins
only through `T` and `E`, and the callbacks it stores must own their state.
Typed leaves keep their exact machine type, including captured origins, inside
the leaf and its slot.

## Sequencing and loops

Entering a program pushes its frames onto one run-loop stack, so evaluation,
unwinding, and disposal never recurse natively. A bind runs only after success,
past a handoff checkpoint that observes cancellation; a recovery runs only on a
failure whose `canceled` flag is false; finalizers run masked with the exact
exit. Callbacks install the program they build directly into the run loop. Small
values and callbacks live inline in their boxes, so a common bind allocates
nothing.

The root task refills one transition budget at each root poll, by default 1,024
(`IORuntimeConfig.auto_yield_threshold`). The budget lives in the root context,
and every run loop under that root, including those inside `both` children and
resources, draws from it through the context it inherits. A run loop reads the
budget once when polled, writes its unspent remainder back before polling a leaf
and when it returns, and returns a runnable wait once the budget is spent. A
leaf poll lends its own transition to the run loops nested inside it and counts
only if they spent nothing, so even a budget of one reaches the innermost
`IO`. A
handoff checks cancellation every `cancelation_check_threshold` binds, by
default every bind. A pending leaf suspends the run loop until its own wake
conditions hold.
Folds, `tail_rec_m`, and recursion through `defer` keep a bounded frame stack:
million-step chains, nested `defer` levels, and tail-recursive loops run under a
1 MiB native stack.

The typed `Bind` and `Loop` machines in `composition.mojo` remain for leaves
built from typed parts. Each of their nodes performs at most one factory
invocation or one active-child poll per outer poll, and their static type depth
is a caller-visible cost. Child groups nest statically: `IO` values inside a pair
each run their own run loop, so a pair's native depth follows its type.

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

The `io_engine`, `io_depth`, `io_family`, and `io_laws` clients cover the run
loop: sequencing, recovery, deferred construction, leaves resuming a chain,
cancellation, iterative disposal, the stack bound, and the monad and recovery
laws. `io_budget` covers the shared per-poll budget across nested run loops,
masked cleanup, and check intervals; `io_stepping` drives one transition per
poll through the public host. The maintained composition, loop lifecycle, child and origin clients cover
move-only state/errors, construction failure, cancellation checkpoints, child
terminal-state combinations, independent external origins, unopened siblings,
parent masking, wake-before-park races, mixed waits, and nested resource cleanup.
Loop probes assert at most one live step and exactly-once state destruction.
Long-loop and static-depth clients also execute under a recorded stack limit.

```sh
pixi run python experiments/async-state-machines/qualify.py \
  --output .cache/async-composition-check --jobs 2 \
  --client io_engine --client io_depth --client io_family \
  --client composition --client loop_lifecycle --client children --client depth
```

Each output directory must be fresh. The runner retains source/package O0/O3
results, raw diagnostics, executable hashes and independent audits. Sustained
loop storage and local sequencing costs are recorded in the
[overnight results](async-qualification.md#overnight-results).

`IO` sequencing has no static depth limit; typed leaves and child groups remain
finite statically typed trees. Neither promises bounded user payload sizes. A
noncooperating poll blocks its host; nonterminating masked cleanup prevents
completion.
