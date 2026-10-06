# Examples

Each example is a complete program in `docs/examples/` that you can run and
change. Run it from the repository root:

```sh
pixi run mojo run -I src docs/examples/<name>.mojo
```

The programs check their results with `std.testing`. Documentation tests also
compile them through source and precompiled package imports at O0 and O3 with
`--Werror`, then compare their output with the output shown on the site.

## Start with pipelines

| Example | What it shows | Page |
|---|---|---|
| `quickstart.mojo` | The smallest complete program: a one-stage `pipe` | [Home](../index.md) |
| `callable_pipeline.mojo` | A pipeline of plain functions over a consumed list, ending in a fold | [Pipelines tutorial](../tutorial/pipelines.md) |
| `callable_pipeline_generic.mojo` | Forwarding a pipeline through a generic function | [Pipelines tutorial](../tutorial/pipelines.md#forward-through-a-generic-function) |
| `chained_pipeline.mojo` | A ten-stage chain with `piped(...).then(...)`: plain functions, closures and partials | [fp.functions](../reference/functions.md#chain-ten-stages-with-piped) |
| `partial.mojo` | Binding leading arguments with `partial`; binding a keyword with a closure | [fp.functions](../reference/functions.md#bind-leading-arguments-with-partial) |

## Iterate and fold

| Example | What it shows | Page |
|---|---|---|
| `iteration.mojo` | Lazy selection, ordered reduction and initial-first snapshots | [Iteration tutorial](../tutorial/iteration.md) |
| `generic_fold.mojo` | One `fold_left` over scalars, SIMD vectors and a user-defined document | [fp.iteration](../reference/iteration.md#fold-scalars-simd-vectors-and-documents-with-one-function) |
| `iteration_generic.mojo` | Returning `map` and `scan_left` adapters from generic functions | [Iteration tutorial](../tutorial/iteration.md#return-adapters-from-generic-functions) |
| `iteration_filtering_generic.mojo` | Returning filtering adapters from generic functions | [Iteration tutorial](../tutorial/iteration.md#return-filtering-adapters) |
| `terminal_generic.mojo` | Generic terminal wrappers that keep the callback's exact error | [Iteration tutorial](../tutorial/iteration.md#generic-terminal-calls) |
| `control_flow.mojo` | `while_loop`, `fori_loop` and carry/output `scan` | [fp.control](../reference/control-flow.md#write-loops-and-a-scan-as-expressions) |

## Handle results and errors

| Example | What it shows | Page |
|---|---|---|
| `results.mojo` | Stored domain errors versus raised callback failures | [Results tutorial](../tutorial/results.md#transform-only-the-active-branch) |
| `result_transform_generic.mojo` | Generic Result transformations | [Results tutorial](../tutorial/results.md#generic-transformations) |
| `attempt_generic.mojo` | A generic transaction helper built on `attempt` | [Results tutorial](../tutorial/results.md#generic-transaction-helpers) |
| `attempt_once.mojo` | Capturing the failure of a consuming thunk | [fp.data](../reference/data.md#attempt_once) |
| `result_once.mojo` | Consuming handlers in Result transformations and folds | [fp.data](../reference/data.md#Result.fold_once) |

## Store values in place

| Example | What it shows | Page |
|---|---|---|
| `foundations.mojo` | Callbacks, folds, typed errors and a `Choice` matched together | [Values stored in place](../tutorial/choices.md#store-a-value-in-a-choice) |
| `optional.mojo` | Matching a standard `Optional` and a `Result`, with a guard | [Values stored in place](../tutorial/choices.md#match-result-optional-and-controlflow) |

## Declare and match data

| Example | What it shows | Page |
|---|---|---|
| `shapes.mojo` | A sum type matched with clauses, a guard, a context and a pair of values | [Matching tutorial](../tutorial/matching.md) |
| `traffic_light.mojo` | Matching two values, and three with a plain one, by every combination of constructors | [Matching tutorial](../tutorial/matching.md#several-values-at-once) |
| `expression.mojo` | Structural recursion over an inductive expression type: evaluation, rendering and rewriting, with `Next` and shared values | [Inductive types tutorial](../tutorial/recursion.md#evaluate-render-and-simplify-an-expression) |
| `file_tree.mojo` | Recursive fields in a `List` and an `Optional` | [Recursion tutorial](../tutorial/recursion.md#lists-and-optional-children) |

## Use algebra and effects

| Example | What it shows | Page |
|---|---|---|
| `algebra_core.mojo` | `pure`, `map`, `flat_map` and `traverse` over four native carriers | [fp.algebra](../reference/algebra.md#use-one-set-of-operations-over-four-carriers) |
| `algebra_choices.mojo` | Mapping, monadic bind, `map2`, `ap` and List's Cartesian combination | [Algebra tutorial](../tutorial/algebra.md#choose-the-operation-by-what-the-next-step-needs) |
| `algebra_traversal.mojo` | `traverse` and `sequence`, early termination and empty input | [Algebra tutorial](../tutorial/algebra.md#collect-results-with-traverse-and-sequence) |
| `effects_reader.mojo` | Pricing configuration with `ask`, `local` and a borrowed deferred callback | [Effects tutorial](../tutorial/effects.md#read-configuration-with-reader) |
| `effects_state.mojo` | Reading, updating and resetting a counter with State | [Effects tutorial](../tutorial/effects.md#pass-an-evolving-counter-through-state) |
| `effects_writer.mojo` | Ordered logs with Writer, `tell`, `listen` and `censor` | [Effects tutorial](../tutorial/effects.md#accumulate-output-with-writer) |
| `state_result.mojo` | How transformer order decides whether a failure keeps its state | [fp.effects](../reference/effects.md#choose-whether-a-failure-keeps-its-state) |

## Build an application

| Example | What it shows | Page |
|---|---|---|
| `config_parser.mojo` | Parsing configuration lazily, collecting Results and validating with a fold that stops early | [Application tutorial](../tutorial/application.md#parse-and-validate-configuration) |
| `job_router.mojo` | Routing a queue of commands with guarded, raising clauses, a context and `attempt` | [Application tutorial](../tutorial/application.md#route-commands-with-guarded-clauses) |
