# 1. Eager Pipelines

To follow along the tutorial, please [install the environment](../start/installation.md) and make sure you understand Mojo's [ownership and errors conventions](../start/ownership.md).

## Example

This example shows how one can build a pipeline that
    (i) consumes a list, removes negative values, and collects the accepted values,
    (ii) then consumes that list and folds it to an integer,
    (iii) and, finally, formats the integer as a string.

It also shows how to gracefully handle errors in an eager pipeline.

<!-- example: docs/examples/callable_pipeline.mojo -->

## Discussion

`pipe(values^, accepted, total, receipt)` infers the stage results as `List[Int]`, then `Int`, then `String`. All stages are plain functions, passed as they are. **Please note that `pipe` accepts up to eight functions / stages**. Mojo accepts a variadic list of functions, but in Mojo 1.1 each element keeps only its type, not its signature, so `pipe` cannot work out a stage's result type from it. That is why `pipe` has a separate overload for each number of plain functions, each spelling every stage's signature. For longer chains, `piped(values^).then(accepted).then(total).then(receipt).get()` applies the same stages one call at a time, with no limit on their number (see [chained pipelines](../reference/functions.md#piped)).

`values^` transfers the input list once. Each intermediate is passed to the next stage with native ownership. `accepted` and `total` hand their list to `filter` and `fold_left` with `^`, which consume a collection directly.

The result is computed before `pipe` returns. There is no reusable `flow` object or deferred closure. Zero-stage `pipe` is identity; one-stage `pipe` accepts a direct callable without the explicit `Results` list.

## Ordered execution and errors

Stages run left to right, once each. A stage failure stops the pipeline before any later stage. For raising stages, `pipe(value, stages...)` infers the exact shared error type. Pure and explicit `raises Never` stages are neutral. Different inhabited errors must be mapped explicitly. The example catches the concrete `ReceiptFailure` produced by the checked stage. A stored `Err` remains an ordinary stage result unless a later stage explicitly interprets it.

A closure is a stage once promoted with `as_unary(closure)`, and library values such as a `Partial` or a `flow(...)` composition are stages as they are. In a `piped(...).then(...)` chain, closures are stages without promotion. When a pipeline mixes them with native functions, promote every native function. The explicit forms `pipe[E=Failure]` and `pipe[Results, Failure]` also take promoted functions and library values. See [fp.functions](../reference/functions.md) for exact overloads.

## Forward through a generic function

A generic helper can preserve its declared result and error while letting `pipe` infer the intermediate types. This example defines its own `forward` helper; it is not a new library operation. Its stages arrive as a variadic pack, so they are library values: the caller promotes the functions with `as_unary`.

<!-- example: docs/examples/callable_pipeline_generic.mojo -->

The compile-time assertion checks that the inferred result is exactly R, including nominal struct identity. `rebind_var[R]` then transfers it across the generic expression boundary. Keep both steps: rebind alone accepts some distinct structs with the same representation on this compiler. The explicit `E=E` connects the pipeline to the helper's declared error; choose Never for a nonraising helper. Fully inferred errors and an unbridged return still encounter generic equality limits on the pinned compiler. The explicit Results path remains an alternative.

Next, inspect the [iteration and fold behavior](iteration.md) used inside these stages.
