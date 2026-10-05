# Functional programming for Mojo

<div class="hero" markdown="1">

FP Mojo is a functional-programming library that works on Mojo's own types.
You chain plain functions with `pipe`, process collections with lazy iterators
and folds, keep failures as typed `Result` values, and declare data types from
your own structs; `fp.match` rejects a match that misses a case when the
program compiles. Callbacks keep their error types: a stage that raises
`ParseError` makes the pipeline raise `ParseError`. The library works with
Mojo 1.1 and is verified on Linux x86-64 and macOS arm64.

```sh
pixi add fp_mojo  # after adding the modular-community channel
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

Chain plain functions with `pipe`, `flow` and `partial`; each intermediate type and error is inferred.
</div>
<div class="card" markdown="1">
[Pattern matching](tutorial/matching.md)

Declare data types from your own structs; a match that misses a case does not compile.
</div>
<div class="card" markdown="1">
[Effects](reference/effects.md)

Use Functor, Monad, and Reader, State and Writer over native values.
</div>
</div>

## Run a first program

After [installing the environment](start/installation.md), run this program from
the repository root.

<!-- example: docs/examples/quickstart.mojo -->

`pipe(21, twice)` calls `twice` once with `21` and returns the `Int` `42`. Add
stages to the same call and they run left to right:
`pipe(value, parse, check, render)`. Each stage's result type, and the error
type of any stage that raises, is inferred. The
[pipeline tutorial](tutorial/pipelines.md) builds a longer pipeline and shows
how a failing stage stops it.

## Choose where to start

| Your task | Start here |
|---|---|
| Learn through runnable programs | [Tutorial](tutorial/pipelines.md) |
| Understand borrowing, movement, and failure | [Ownership and errors](start/ownership.md) |
| Look up a function or type | [API reference](reference/index.md) |
| Understand the implementation boundaries | [Architecture](architecture/overview.md) |
| Browse every runnable example | [Examples](examples/index.md) |
| Contribute | [Development](contributing/development.md) |
