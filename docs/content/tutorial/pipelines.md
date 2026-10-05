# 1. Eager Pipelines

`pipe` passes a value through a chain of functions, left to right, and returns
the last result straight away. You write each stage as a plain function, and
`pipe` infers every intermediate type and the error type of any stage that
raises. A call takes up to eight plain functions; `piped(...).then(...)` has no
such limit. This chapter assumes an [installed environment](../start/installation.md)
and Mojo's [ownership and error conventions](../start/ownership.md).

## Run a pipeline over a list

The program below consumes a list, keeps the values that are not negative, adds
them up and formats the total. A second pipeline shows a stage that raises.

<!-- example: docs/examples/callable_pipeline.mojo -->

`pipe(values^, accepted, total, receipt)` starts from `[3, -2, 7, 0]`.
`accepted` returns `[3, 7, 0]`, `total` returns `10`, and `receipt` returns
`"total=10"`. The stage results are inferred as `List[Int]`, then `Int`, then
`String`. Every stage is a plain function, passed as it is.

`values^` moves the input list into the pipeline once. Each result is passed to
the next stage with native ownership. `accepted` and `total` hand their list to
`filter` and `fold_left` with `^`, which consume a collection directly.

The result is computed before `pipe` returns: there is no reusable pipeline
object or deferred closure. `pipe(value)` with no stages returns the value, and
a one-stage `pipe` takes a callable directly, without the explicit `Results`
list.

## Choose a pipeline form

How many stages a call takes depends on the form:

- `pipe` takes up to eight plain functions. Mojo 1.1 keeps only the type of
  each element of a variadic list of functions, not its signature, so `pipe`
  cannot work out a stage's result type from it. `pipe` therefore has one
  overload per number of plain functions, each spelling every stage's
  signature.
- `piped(values^).then(accepted).then(total).then(receipt).get()` applies the
  same stages one call at a time, with no limit on their number. See
  [chained pipelines](../reference/functions.md#piped).

## Stop at the first failure

Stages run left to right, once each. When a stage raises, the pipeline stops and
no later stage runs. In the example, `pipe(-4, checked, receipt)` raises
`ReceiptFailure(-4)` from `checked`, so `receipt` never runs, and the `except`
block reads `invalid_total` as `-4`.

For raising stages, `pipe` infers the one error type they share. Stages that do
not raise, or declare `raises Never`, add nothing to it. Stages that raise
different error types do not compile together; map their errors to one type
first. A stage that returns a `Result` holding `Err` has not failed: the `Result`
is an ordinary value that the next stage receives.

## Mix closures and library values

A closure becomes a stage once you promote it with `as_unary(closure)`. Library
values such as a `Partial` or a `flow(...)` composition are stages as they are.
In a `piped(...).then(...)` chain, closures are stages without promotion.

When a `pipe` call mixes closures or library values with native functions,
promote every native function too. The explicit forms `pipe[E=Failure]` and
`pipe[Results, Failure]` also take promoted functions and library values. See
[fp.functions](../reference/functions.md) for the exact overloads.

## Forward through a generic function

A generic helper can keep its declared result and error types while `pipe`
infers the types in between. The `forward` helper below belongs to the example;
it is not a library operation. Its stages arrive as a variadic pack, so they are
library values: the caller promotes the functions with `as_unary`.

<!-- example: docs/examples/callable_pipeline_generic.mojo -->

`forward[Int, Failure](123, first, last)` labels `123` as `"123"` and returns
its length, `3`. With `-7`, `label` raises `Failure(-7)`, and the caller catches
it with its exact type and reads `code` as `-7`.

The helper needs both of its last two lines:

- `comptime assert type_of(result) == R` checks that the inferred result is
  exactly `R`, including nominal struct identity.
- `rebind_var[R]` then moves the result across the generic expression boundary.
  On this compiler, a rebind alone accepts some distinct structs with the same
  representation, so keep the assertion next to it.

`pipe[E=E]` connects the pipeline to the helper's declared error; use `Never`
for a helper that does not raise. On the pinned compiler, a fully inferred error
or a return without the rebind still hits generic type-equality limits. The
explicit `Results` path is an alternative.

Next, see how the [folds and lazy iterators](iteration.md) used inside these
stages pull their values.
