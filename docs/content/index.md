# Functional programming for Mojo

<div class="hero" markdown="1">

FP Mojo is a functional programming library for Mojo. You can compose functions
into pipelines, map, filter, and fold over collections, handle failures with
typed `Result` values, and define algebraic and inductive data types from your
own structs. Pattern matching checks that every constructor is covered at
compile time. Functions and closures keep their native ownership conventions
and error types.

The library is verified with Mojo 1.1.0 on Linux x86-64 and macOS arm64.

```sh
pixi add fp_mojo "mojo==1.1.0"  # after adding the modular-community channel
```

<div class="hero-actions" markdown="1">
[Get started](start/installation.md){ .button .primary }
[Tutorial](tutorial/pipelines.md){ .button }
[API reference](reference/index.md){ .button }
</div>

</div>

<div class="cards" markdown="1">
<div class="card" markdown="1">
[Pipelines](tutorial/pipelines.md)

Apply functions with `pipe`, compose them with `flow`, and bind arguments with
`partial`. Intermediate types and callback errors are inferred.
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

Follow the [package installation steps](start/installation.md#install-the-package),
then save this program as `quickstart.mojo` beside your project's `pixi.toml`:

<!-- source: docs/examples/quickstart.mojo -->

```sh
pixi run mojo run quickstart.mojo
```

The program prints `42`. `pipe(21, twice)` calls `twice` once with `21` and
returns that `Int` result. Add stages to the same call and they run left to right:
`pipe(value, parse, check, render)`. Each stage's result type, and the error
type of any stage that raises, is inferred. The
[pipeline tutorial](tutorial/pipelines.md) builds a longer pipeline and shows
how a failing stage stops it.

## Choose where to start

| Your task | Start here |
|---|---|
| Learn through runnable programs | [Tutorial](tutorial/pipelines.md) |
| Choose between mapping, combination and bind | [Functors, applicatives and monads](tutorial/algebra.md) |
| Compose configuration, state and logging | [Reader, State and Writer](tutorial/effects.md) |
| Understand borrowing, movement, and failure | [Ownership and errors](start/ownership.md) |
| Look up a function or type | [API reference](reference/index.md) |
| Understand the implementation boundaries | [Architecture](architecture/overview.md) |
| Browse every runnable example | [Examples](examples/index.md) |
| Contribute | [Development](contributing/development.md) |
