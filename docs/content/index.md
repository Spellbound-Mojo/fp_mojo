# Functional programming for Mojo language

FP Mojo is a functional-programming library for Mojo: pipelines and composition,
partial application, lazy iterators and folds, typed results, algebraic and
recursive data with exhaustive pattern matching evaluated in a loop, functional
control flow, and Functor/Applicative/Monad instances with Reader, State and
Writer transformers.

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
