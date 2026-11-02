# Functional programming for Mojo

<div class="hero" markdown="1">

FP Mojo is a functional programming toolkit and structured asynchronous runtime
for Mojo. It combines composable functional abstractions—fluent pipelines,
zero-allocation lazy iterators, pure monadic effects, and compile-time exhaustive
pattern matching—with a high-performance concurrency engine. Programs coordinate
asynchronous I/O through lightweight cancelable fibers, cooperative work-stealing
scheduling, and deterministic virtual-time testing, all while preserving Mojo's
native argument conventions (`var`, `ref`, `mut`), explicit memory ownership,
and exact compiler error types without runtime overhead.

The documentation describes FP Mojo 1.0.2, which requires Mojo 1.2.0.
[Install the package](start/installation.md#install-the-package), or follow the
[checkout instructions](start/installation.md#work-from-a-checkout) to work from
source.

<div class="hero-actions" markdown="1">
[Get started](start/installation.md){ .button .primary }
[Tutorial](tutorial/pipelines.md){ .button }
[API reference](reference/index.md){ .button }
</div>

</div>

<div class="cards" markdown="1">
<div class="card" markdown="1">
[Pipelines & composition](tutorial/pipelines.md)

Build fluent data-transformation pipelines with `pipeline`, compose reusable stages
with `flow`, and bind arguments with `partial`. Native functions, closures, and
library callables interoperate seamlessly with exact error propagation.
</div>
<div class="card" markdown="1">
[Pattern matching & ADTs](tutorial/matching.md)

Model domain structures with algebraic sum types (`Choice`) and recursive trees (`Node`).
Inspect variants safely using compile-time exhaustive pattern matching and expressive guards.
</div>
<div class="card" markdown="1">
[Pure effects & transformers](tutorial/effects.md)

Manage application dependencies, mutable state, and structured logs with `Reader`, `State`,
and `Writer`. Stack independent effect layers predictably using composable monad transformers.
</div>
<div class="card" markdown="1">
[Structured concurrency](guides/async-runtime.md)

Coordinate asynchronous I/O and parallel workloads with `IO`. Spawn lightweight cancelable
fibers, combine branches with `both` and `race`, safely offload blocking tasks, and
verify timing deterministically with `TestControl`.
</div>
</div>

## Run a first program

To verify your installation, follow the [checkout steps](start/installation.md#work-from-a-checkout)
and execute this sample from the repository root:

<!-- example: docs/examples/pipeline_quickstart.mojo -->

The program executes and prints `42`. Calling `pipeline(21).then(twice).get()` evaluates
`twice` once and extracts the computed integer. You can append additional `.then(...)`
stages to transform values, or use `.map(...)` and `.filter(...)` over collections and
optional payloads. When working with raising native closures, declare the error type
explicitly via `.raising[MyError]()`; plain raising functions infer their error automatically.
The [pipeline tutorial](tutorial/pipelines.md) explores multi-stage pipelines and
fail-fast error handling in depth.

## Choose where to start

| Your task | Start here |
|---|---|
| Choose Result methods, pipelines, lazy iteration or native capture | [Choose an API](start/choosing-api.md) |
| Learn through runnable programs | [Tutorial](tutorial/pipelines.md) |
| Choose between mapping, combination and bind | [Functors, applicatives and monads](tutorial/algebra.md) |
| Compose configuration, state and logging | [Reader, State and Writer](tutorial/effects.md) |
| Collect every independent error | [Accumulating errors](tutorial/accumulation.md) |
| Write async programs step by step | [Programs with IO](tutorial/io.md) |
| Coordinate concurrent fibers, timers and async IO | [Structured async runtime](guides/async-runtime.md) |
| Understand borrowing, movement, and failure | [Ownership and errors](start/ownership.md) |
| Look up a function or type | [API reference](reference/index.md) |
| Understand the implementation boundaries | [Architecture](architecture/overview.md) |
| Browse every runnable example | [Examples](examples/index.md) |
| Contribute | [Development](contributing/development.md) |
