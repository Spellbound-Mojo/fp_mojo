# 7. A configuration processor

This complete program turns lines of configuration into a validated message. It connects lazy iteration, Result aggregation, a fold that stops early and a pipeline.

## Define the policy at each boundary

1. Parse each `key=value` line into `Result[Entry, ConfigError]`, lazily with
   `map`.
2. Stop at the first parse `Err` with `collect_results`.
3. Validate the parsed entries with `parsed^.flat_map(validate)`. `validate`
   folds them into a `Config` with `fold_until`: a step returns `Continue` with
   the updated configuration, or `Break` with the first error, and `fp.match`
   turns the outcome into a Result.
4. Format only a valid `Config` with `checked^.map(describe)`.
5. Match the final `Ok` or `Err` into one message.

The three steps after parsing are plain functions, so `pipe(..., check, render,
finish)` chains them without promotion.

Parsing deliberately translates a native integer-conversion error into a domain
`ConfigError`. That policy is visible inside `parse`; Result and the iterator do
not implicitly catch arbitrary callback failures.

<!-- example: docs/examples/config_parser.mojo -->

## Read the scenarios as contracts

`batch` and `workers` must each appear once, use positive integers, and satisfy
`workers <= batch`. Syntax and integer errors stop parsing at once: `configure`
counts the lines it parsed, and a bad second line leaves the third unread.
Validation errors occur after complete parsing, because validation depends on
the whole collection.

## A second application: routing commands

The job router dispatches submitted and retried jobs when a guard allows them
and defers every other command. Guards and dispatches record a trace through the
match's context, and one dispatch raises a typed error. The queue is routed
lazily with `map`; because a lazy callback cannot raise, `attempt` keeps each
failure as an `Err`, and `fp.match` turns each outcome into a line.

<!-- example: docs/examples/job_router.mojo -->

When adapting these examples, preserve explicit error policy and source ownership. Use [API reference](../reference/index.md) for a declaration, [architecture](../architecture/overview.md) for an implementation boundary, and [troubleshooting](../guides/troubleshooting.md) for admission failures.
