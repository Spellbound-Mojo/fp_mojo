# 7. A configuration processor

In this example we build a complete program that turns lines of configuration into a validated message. The aim of this example is to showcase various aspects of the library.

## Specification

There are some rules we want a program to observe:

1. Parse each `key=value` line into `Result[Entry, ConfigError]`.
2. Stop at the first parse Err with `collect_results`.
3. Validate the completed entry list with `parsed^.flat_map(validate)`.
4. Format only a valid Config with `checked^.map(describe)`.
5. Fold the final Ok or Err into one message with `fold`.

We also want to express business logic as plain functions avoiding unnecessary ceremony and boilerplate code.  

<!-- example: docs/examples/config_parser.mojo -->

## A second application: routing commands

The job router dispatches submitted and retried jobs when a guard allows them
and defers every other command. Guards and dispatches record a trace through the
match's context, and one dispatch raises a typed error. Every route is compared
with a hand-written branch, trace included.

<!-- example: docs/examples/job_router.mojo -->
 