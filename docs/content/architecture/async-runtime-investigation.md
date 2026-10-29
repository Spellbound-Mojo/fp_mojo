# Async runtime investigation

This is an experimental assessment from October 28, 2026, for discussion before
selecting an implementation. It does not introduce a runtime or change the public
IO contract. All new execution probes are Mojo. A temporary C context backend is
an alternative under consideration, not an approved implementation decision.

Subsequently, the user selected explicit state machines in pure Mojo and
accepted a substantial redesign. The [state-machine foundation](async-state-machines.md)
records that decision, its private prototype, and qualification results. The
alternatives and recommendation below preserve the earlier investigation.

## Environment and scope

The investigation used Mojo **1.2.0 (2016d0cd)** and an isolated checkout of
`nightly` at `5d9197a36311988019375a0377480ff6b21ecdcf`. The original workspace
checkout and its Mojo 1.1 environment were retained. The probe environment was
installed from the target commit's Pixi manifest and lockfile.

Tests exercised the compiler's private coroutine hooks directly and, for one
comparison, its private task runtime. They are capability probes, not supported
library implementations. Neither the compiler nor the standard library was
modified. No C backend was reconstructed or tested during this investigation.

## Observed results

| Probe | O0 | O3 | What it establishes |
|---|---|---|---|
| Two explicit suspension points, manually resumed | Passed | Passed | Basic coroutine suspension works. |
| Local move-only owner and pointer borrowing its String across suspension | Passed | Passed | Heap contents remain readable; the owner is destroyed exactly once after use. |
| Exact move-only error returned in the library's `Outcome[T,E]` | Passed | Passed | An explicit outcome preserves E without using coroutine `raises E`. |
| Cancellation and masked cleanup, both stages in one coroutine | Passed | Passed | Four success/cancellation/cleanup-failure combinations preserve existing outcome policy and release once. |
| Calling a precompiled coroutine module | Passed | Passed | Basic suspension also works through a `.mojoc` import. |
| Explicit outcomes and flat cleanup against precompiled `fp` | Passed | Passed | These cases are not limited to source imports. |
| Returning a coroutine borrowing a local as a capture-free coroutine | Rejected | Rejected | The tested escape is rejected for mismatching captured origins. |
| Minimal nested `await`, manual driver | LLVM lowering failure | Passed | Optimization changes whether this valid-looking composition compiles. |
| Minimal nested `await`, private standard runtime | Same LLVM lowering failure | Passed | The failure is not specific to the manual driver. |
| Nested coroutine borrowing an owner on its parent's frame | Compiler crash | Passed | This borrowed composition is not reliable across optimization levels. |
| Moving a String into an async function | Rejected | Rejected | The tested owned-argument encoding reports use of the moved, uninitialized argument. |
| Capturing a suspended child handle in a mailbox | IR verification failure | Passed | The tested scheduling hook is optimization-sensitive. |
| Resource body awaiting separate masked cleanup, returning exact outcomes | Compiler crash | Compiler crash | This essential composition has not been validated. |

The minimal nested-await diagnostic is `cannot guarantee tail call due to
mismatched return types`. The resource probe was also tried without `_ExitState`,
retaining the body outcome directly; that alternative still failed at O3 with
lowering diagnostics and a compiler crash. An earlier mailbox encoding timed
out after 90 seconds; that is a failed attempt, not a rejection test or a proof
of impossibility.

Directly awaiting a coroutine declared with a custom `raises Failure` exposed
the standard `Error` type to the catch clause in the tested encoding. Returning
the existing explicit `Outcome` is a demonstrated alternative. Likewise,
borrowed pointers to externally retained input storage worked in cases where
moving an argument into the coroutine did not. These alternatives matter: one
rejected encoding does not rule out every library representation.

The passing flat cleanup test uses `_settle`, `_ExitState`, `_finish`, and
`IOContext` masking from the actual library. Its two suspension points live in
one async function. It does **not** demonstrate arbitrary composition through
the existing `guarantee`, `IOResource`, or `ScopedIO` APIs, nor a complete scheduler.
The composed probe attempted a separate async cleanup borrowing the resource
and masked context; its failure remains material.

No active coroutine was intentionally destroyed to simulate cancellation in a
passing runtime probe. Cancellation was requested, execution resumed through
cleanup, and the handle destroyed only after completion. Upstream explicitly
documents that destroying a suspended coroutine can skip cleanup of linear
values; handle destruction cannot substitute for Cats Effect cancellation.

## Compatibility boundary

Current `IO` is a concrete `ReaderT` composition whose compatible `run` returns a
completed `Outcome`. Resource acquisition, use, release, and finalization execute
through synchronous native calls. The compiler can suspend an async function
and its awaited async children; it does not automatically turn an arbitrary
synchronous `ReaderAction.run` body into a resumable computation.

A probe placing suspension behind a non-inlined synchronous function failed
during lowering. Built-in recipe nodes could gain a resumable interpretation,
but custom native endpoints would still need a defined boundary: execute
synchronously as one step, or implement an explicit suspending protocol.

This distinction will remain relevant when public Mojo async stabilizes. It is
a control-flow/API issue in addition to today's compiler reliability issues.

## Alternatives

### Private native coroutines

This gives compact compiler-managed frames and can preserve local owners and
origins in demonstrated cases. Exact library errors can travel as values. It
requires private hooks and a resumable execution contract, with current compiler
failures in important compositions. Keep it experimental; the evidence does not
support choosing it as the production foundation on Mojo 1.2.

### Explicit resumable computations in pure Mojo

Represent the next computation and its state in ordinary typed structs, with a
cooperative run loop. Cats Effect's run loop is a useful semantic model, while
Mojo's owners and origins must remain part of the concrete representation.

This avoids dependency on unfinished compiler async lowering. It requires a
substantial execution-contract change. Reuse or generalize the existing algebra,
outcome, and resource owners rather than duplicating them. Retaining a scoped
computation borrowing a resource across returned steps is a proof obligation;
a simple state machine does not establish that the whole resource contract can
be supported. This alternative was assessed architecturally, not implemented.

### Temporary C stackful context backend

The recovered architecture preserves ordinary synchronous Mojo call stacks,
which makes it the closest fit for existing custom IO and scoped resource
bodies. Keep the C boundary limited to opaque contexts, guarded stack storage,
and wake primitives. Scheduling, typed outcomes, callback state, cancellation,
masking, and resource policy belong in Mojo.

Costs include the native build dependency, the recovered implementation's
64-bit Linux restriction, fixed stack storage, and the obligation to reconstruct
and freshly validate the recovered sources and corrections. Historical logs
are not current verification. This approach remains cooperative: a blocking
native call blocks its scheduler thread, and CPU loops need cooperation.

If selected, isolate the backend and maintain backend-independent behavioral
tests. Do not promise that a future stackless runtime can replace it through a
context-switch function alone. A future native implementation may require new
resumable endpoints while the C backend continues to serve existing endpoints.

## Recommendation for discussion

Prefer the narrow temporary C backend if preserving current direct-style IO and
resource contracts is the near-term priority. Prefer explicit resumable Mojo
computations if eliminating the native dependency immediately is more important
and a broader execution/API redesign is acceptable. Native coroutines should
remain an experimental track until the necessary composition cases pass
consistently. No option has been implemented as a production runtime here.

## Evidence and reproduction

Local probe sources, raw compiler output, execution output, and timeouts are
retained under `/workspace/fp_mojo/.cache/async-investigation/`. The JSON index is
`investigation-report.json`; `results/*/report.json` contains individual commands
and outputs. Later runs also retain source snapshots and hashes. Early reports
predate snapshot capture and include intermediate failed encodings.

Run a selected probe in the isolated environment:

```sh
cd /workspace/fp_mojo/.cache/async-investigation
/workspace/.tools/bin/pixi run --manifest-path environment/pixi.toml \
  python /workspace/fp_mojo/.cache/async-investigation/run_probe.py basic -O 0
```

Use `-O 3` for optimized builds. `--library` selects the precompiled `fp` directory;
`--reject` compiles without executing a rejection probe. The runner records
outcomes; its process exit code alone is not a test verdict. Compiler crashes and
timeouts are failures. The full existing library suite was not run because no
production source changed; a strict precompile of the target `fp` succeeded.

Upstream references:

- [Mojo 1.2 coroutine implementation](https://github.com/modular/modular/blob/mojo/v1.2.0/Mojo/stdlib/std/builtin/_coroutine.mojo)
- [Mojo 1.2 private task runtime](https://github.com/modular/modular/blob/mojo/v1.2.0/Mojo/stdlib/std/runtime/_asyncrt.mojo)
- [Mojo async design proposal](https://github.com/modular/modular/blob/cb987e0e4f4df28d19f04dd586dc76713751cf65/Mojo/proposals/async-design.md)
- [Cats Effect run loop](https://github.com/typelevel/cats-effect/blob/series/3.x/core/shared/src/main/scala/cats/effect/IOFiber.scala)
- [Cats Effect Async contract](https://github.com/typelevel/cats-effect/blob/series/3.x/kernel/shared/src/main/scala/cats/effect/kernel/Async.scala)
