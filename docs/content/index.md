# Functional programming for Mojo language

<div class="hero" markdown="1">

FP Mojo is a functional-programming library for Mojo: pipelines and composition,
partial application, lazy iterators and folds, typed results, algebraic and
recursive data with exhaustive pattern matching evaluated in a loop, functional
control flow, and Functor/Applicative/Monad instances with Reader, State and
Writer transformers.

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

`pipe`, `flow` and `partial`, with every intermediate type and error inferred.
</div>
<div class="card" markdown="1">
[Pattern matching](tutorial/matching.md)

Data types from your own structs, with matches checked when the program compiles.
</div>
<div class="card" markdown="1">
[Effects](reference/effects.md)

Functor, Monad, and Reader, State and Writer over native values.
</div>
</div>

## First program

After [installing the environment](start/installation.md), run this program from the repository root.

<!-- example: docs/examples/quickstart.mojo -->

`pipe` implements eager chaining. The callback executes once and returns an ordinary `Int`. One can chain several plain functions in a similar way: `pipe(value, parse, check, render)` or `piped(value).then(parse).then(check).then(render).get()`. Note that intermediate types, including error types, are inferred. See more on piping in [our tutorial](tutorial/pipelines.md).

## Ways to explore

| Your task | Start here |
|---|---|
| Learn through runnable programs | [Tutorial](tutorial/pipelines.md) |
| Understand borrowing, movement, and failure | [Ownership and errors](start/ownership.md) |
| Look up a function or type | [API reference](reference/index.md) |
| Understand the implementation boundaries | [Architecture](architecture/overview.md) |
| Browse every runnable example | [Examples](examples/index.md) |
| Contribute | [Development](contributing/development.md) |
