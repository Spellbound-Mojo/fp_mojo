# Functional programming for Mojo language

FP Mojo is a functional-programming library for Mojo: pipelines and composition,
partial application, lazy iterators and folds, typed results, algebraic and
recursive data with exhaustive pattern matching evaluated in a loop, functional
control flow, and Functor/Applicative/Monad instances with Reader, State and
Writer transformers.

## Start with a complete program

After [installing the environment](start/installation.md), run this program from the repository root.

<!-- example: docs/examples/quickstart.mojo -->

There is no deferred computation here. The callback executes once and returns an ordinary `Int`. Several plain functions chain the same way, `pipe(value, parse, check, render)`, with each intermediate type inferred; the [first tutorial](tutorial/pipelines.md) shows how.

## Choose a path

| Your task | Start here |
|---|---|
| Learn through runnable programs | [Tutorial](tutorial/pipelines.md) |
| Understand borrowing, movement, and failure | [Ownership and errors](start/ownership.md) |
| Look up a function or type | [API reference](reference/index.md) |
| Understand the implementation boundaries | [Architecture](architecture/overview.md) |
| Browse every runnable example | [Examples](examples/index.md) |
| Change the library | [Development](contributing/development.md) |

## What fits together

Native iterators and owned collections feed lazy adapters and terminal folds. `Result` carries domain outcomes through chained method calls. Data types declared from ordinary structs are stored in place or shared, and matched with clauses, one per constructor; recursive values are evaluated in a loop. `Result`, `ControlFlow` and the standard `Optional` are matched the same way.

Borrowed operations inspect existing data; owned operations transfer selected values. Native errors propagate through a common explicit type, independently of stored `Err`, normal no-match, and iterator exhaustion.

Every program on this site is included from a maintained `.mojo` file and is
compiled and run through source and packaged imports at O0 and O3. Reference
declarations are generated from the source. Tests are evidence for the
documented contracts, not proofs over every possible callback or type.
