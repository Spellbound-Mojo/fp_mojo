# Examples

Every program below is a complete, maintained file in `docs/examples/`. Each one
asserts its own results, and the documentation tests compile and run it through
source and precompiled-package imports at O0 and O3 with `--Werror`, comparing its
output with the expected output shown on its page. Run any of them from the
repository root:

```sh
pixi run mojo run -I src docs/examples/<name>.mojo
```

## Getting started

| Example | What it shows | Page |
|---|---|---|
| `quickstart.mojo` | The smallest complete program: `identity` and `pipe` | [Home](../index.md) |
| `callable_pipeline.mojo` | A pipeline of plain functions over a consumed list, ending in a fold | [Pipelines tutorial](../tutorial/pipelines.md) |
| `callable_pipeline_generic.mojo` | Forwarding a pipeline through a generic function | [Pipelines tutorial](../tutorial/pipelines.md#forward-through-a-generic-function) |
| `chained_pipeline.mojo` | A ten-stage chain with `piped(...).then(...)`: plain functions, closures and partials | [fp.functions](../reference/functions.md#chained-pipelines) |
| `partial.mojo` | Binding leading arguments with `partial`; binding a keyword with a closure | [fp.functions](../reference/functions.md#partial-application) |

## Iteration and folds

| Example | What it shows | Page |
|---|---|---|
| `iteration.mojo` | Lazy selection, ordered reduction and initial-first snapshots | [Iteration tutorial](../tutorial/iteration.md) |
| `generic_fold.mojo` | One `fold_left` over scalars, SIMD vectors and a user-defined document | [fp.iteration](../reference/iteration.md#examples) |
| `iteration_generic.mojo` | Returning `map` and `scan_left` adapters from generic functions | [Iteration tutorial](../tutorial/iteration.md#return-adapters-from-generic-functions) |
| `iteration_filtering_generic.mojo` | Returning filtering adapters from generic functions | [Iteration tutorial](../tutorial/iteration.md#return-filtering-adapters) |
| `terminal_generic.mojo` | Generic terminal wrappers that keep the callback's exact error | [Iteration tutorial](../tutorial/iteration.md#generic-terminal-calls) |
| `control_flow.mojo` | `while_loop`, `fori_loop` and carry/output `scan` | [fp.control](../reference/control-flow.md) |

## Results and errors

| Example | What it shows | Page |
|---|---|---|
| `results.mojo` | Stored domain errors versus raised callback failures | [Results tutorial](../tutorial/results.md) |
| `result_transform_generic.mojo` | Generic Result transformations | [Results tutorial](../tutorial/results.md#generic-transformations) |
| `attempt_generic.mojo` | A generic transaction helper built on `attempt` | [Results tutorial](../tutorial/results.md#generic-transaction-helpers) |
| `attempt_once.mojo` | Capturing the failure of a consuming thunk | [fp.data](../reference/data.md#attempt_once) |
| `result_once.mojo` | Consuming handlers in Result transformations and folds | [fp.data](../reference/data.md#Result.fold_once) |

## Values stored in place

| Example | What it shows | Page |
|---|---|---|
| `foundations.mojo` | Callbacks, folds, typed errors and a `Choice` matched together | [Values stored in place](../tutorial/choices.md#a-choice) |
| `optional.mojo` | Matching a standard `Optional` and a `Result`, with a guard | [Values stored in place](../tutorial/choices.md#result-optional-and-controlflow) |

## Data and matching

| Example | What it shows | Page |
|---|---|---|
| `shapes.mojo` | A sum type matched with clauses, a guard, a context and a pair of values | [Matching tutorial](../tutorial/matching.md) |
| `traffic_light.mojo` | Matching two values, and three with a plain one, by every combination of constructors | [Matching tutorial](../tutorial/matching.md#several-values-at-once) |
| `expression.mojo` | A recursive type evaluated, rendered and rewritten; `Next`, sharing and a million-deep value | [Recursion tutorial](../tutorial/recursion.md) |
| `file_tree.mojo` | Recursive fields in a `List` and an `Optional` | [Recursion tutorial](../tutorial/recursion.md#lists-and-optional-children) |

## Algebra and effects

| Example | What it shows | Page |
|---|---|---|
| `algebra_core.mojo` | `pure`, `map`, `flat_map` and `traverse` over four native carriers | [fp.algebra](../reference/algebra.md#examples) |
| `state_result.mojo` | How transformer order decides whether a failure keeps its state | [fp.effects](../reference/effects.md#examples) |

## Applications

| Example | What it shows | Page |
|---|---|---|
| `config_parser.mojo` | Parsing configuration lazily, collecting Results and validating with a fold that stops early | [Application tutorial](../tutorial/application.md) |
| `job_router.mojo` | Routing a queue of commands with guarded, raising clauses, a context and `attempt` | [Application tutorial](../tutorial/application.md) |

