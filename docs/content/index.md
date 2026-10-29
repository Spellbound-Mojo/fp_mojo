# Functional programming for Mojo

<div class="hero" markdown="1">

FP Mojo is a functional programming library for Mojo. You can compose functions
into pipelines, map, filter, and fold over collections, handle failures with
typed `Result` values, and define algebraic and inductive data types from your
own structs. Pattern matching checks that every constructor is covered at
compile time. Functions and closures keep their native ownership conventions
and error types.

These tutorials target the `nightly` checkout, which pins Mojo 1.2.0. Its verified
Linux checkpoint passes the full positive and rejection suites; the [compatibility inventory](guides/compatibility.md)
records API migration and remaining restrictions. The published FP Mojo 1.0.0
package still uses Mojo 1.1.0. Follow the [checkout instructions](start/installation.md#work-from-a-checkout)
for the current API; [package installation](start/installation.md#install-the-package)
documents the existing release separately.

<div class="hero-actions" markdown="1">
[Get started](start/installation.md){ .button .primary }
[Tutorial](tutorial/pipelines.md){ .button }
[API reference](reference/index.md){ .button }
</div>

</div>

<div class="cards" markdown="1">
<div class="card" markdown="1">
[Pipelines](tutorial/pipelines.md)

Chain operations with `pipeline`, compose reusable functions with `flow`, and
bind arguments with `partial`. Plain functions, closures and library callables
work together without adapters in a fluent chain.
</div>
<div class="card" markdown="1">
[Pattern matching](tutorial/matching.md)

Define algebraic and inductive data types, then handle their constructors with
exhaustive pattern matching.
</div>
<div class="card" markdown="1">
[Effects](tutorial/effects.md)

Compose Reader, State and Writer computations with Functor, Applicative and
Monad operations. Combine effects with monad transformers.
</div>
</div>

## Run a first program

Follow the [checkout steps](start/installation.md#work-from-a-checkout), then run
this program from the repository root:

<!-- example: docs/examples/pipeline_quickstart.mojo -->

The program prints `42`. `pipeline(21).then(twice).get()` calls `twice` once
and returns its `Int` result. Add `.then(...)` stages to continue with whole
values, or use `.map(...)` and `.filter(...)` for selected payloads. For native
callbacks that raise, select their error once with `.raising[MyError]()`. The
[pipeline tutorial](tutorial/pipelines.md) builds a longer pipeline and shows
how a failing stage stops it.

## Choose where to start

| Your task | Start here |
|---|---|
| Choose Result methods, pipelines, lazy iteration or native capture | [Choose an API](start/choosing-api.md) |
| Learn through runnable programs | [Tutorial](tutorial/pipelines.md) |
| Choose between mapping, combination and bind | [Functors, applicatives and monads](tutorial/algebra.md) |
| Compose configuration, state and logging | [Reader, State and Writer](tutorial/effects.md) |
| Understand borrowing, movement, and failure | [Ownership and errors](start/ownership.md) |
| Look up a function or type | [API reference](reference/index.md) |
| Understand the implementation boundaries | [Architecture](architecture/overview.md) |
| Browse every runnable example | [Examples](examples/index.md) |
| Contribute | [Development](contributing/development.md) |
