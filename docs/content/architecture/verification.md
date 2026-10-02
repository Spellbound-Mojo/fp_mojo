# Verification

Every claim on this site is backed by a test that the verification gates run.
Correctness claims cover the documented contracts and the tested host
specializations. They are not formal proofs, and they do not establish that
arbitrary user callbacks are lawful, or that code runs on a device.

## Test layers

| Layer | Location | What it establishes | What it does not |
|---|---|---|---|
| Runtime | `tests/runtime/` (88 programs) | Values, ordering, source pulls and composed use | Every possible type or callback |
| Ownership | `tests/ownership/` (56) | Liveness, copies, moves and exactly-once cleanup | A universal destructor order |
| Laws | `tests/laws/` (5) | The [laws](laws.md) under their stated assumptions | Proofs over arbitrary programs |
| Integration | `tests/integration/` (15) | Several packages working together | — |
| Compile-failure | `tests/compile_fail/` (287) | Invalid ownership, origins, descriptors, clauses and error combinations are rejected with the declared diagnostic | That a rejected encoding is impossible in general |
| Examples | `docs/examples/` (27, plus the device host control) | Every program on this site compiles and prints its reviewed output, through source and package imports at O0 and O3 | Behavior beyond those programs |
| Benchmarks | `tests/benchmarks/` (2) | Library code against hand-written loops on identical inputs, reported as diagnostics | A performance guarantee |
| Tooling | `tests/tooling/` | The runners' audit rules | — |

Each runtime, ownership, law and integration program has a `main` that asserts
its results with `std.testing`. `pixi run suite` builds these programs, the
examples and the benchmarks into four executables and runs them as one suite;
each program stays standalone and fails alone (see
[development](../contributing/development.md#verification-gates)). A
compile-failure program declares the diagnostics it must produce in `# error:`
comment lines; `pixi run compile-fail` compiles each one separately, requires
each diagnostic, checks the useful cause rather than exact compiler wording, and
never executes a program the compiler unexpectedly accepts.

## Import routes and optimization levels

Library code is checked four ways: importing the source tree (`-I src`) and
importing a precompiled package (`fp.mojoc`), each at O0 and O3. The suite runs
against a package at O3 by default; `--source` and `--optimization 0` select the
other routes, and `docs-test` runs every example on all four. A package
precompile additionally type-checks generic declarations that no client
instantiates, so it catches trait and signature errors that client builds miss.
Some Mojo 1.1 defects appear only at one optimization level (see
[native boundaries](native-boundaries.md#known-compiler-defects)), which is why
both levels are run.

## Adversarial fixtures

Tests do not rely on integers alone. They use:

- move-only resources, large explicitly copied values, reference-bearing views,
  shared handles, callbacks with visible invocation state, and payloads that
  count their construction and destruction;
- deliberately non-associative operations (subtraction) to expose evaluation
  order, several SIMD widths and element types for genericity, and floating-point
  checks that keep native operation order, classify NaNs and distinguish signed
  zero;
- external sums with three or more cases, identical payload types in different
  constructors, nested Optional and Result data;
- iterators that fail if pulled after a required stop, to detect lookahead;
- recursive data types with several recursive constructors, including list
  and optional children, matched and rewritten on leaves, chains, balanced
  trees, shared values, failing clauses and resource-bearing results, compared
  with hand-written recursion and with values a million levels deep;
- string arguments whose heap contents are checked, not only their length (a
  `String`'s `byte_length()` reads inline metadata and can hide a dangling
  buffer).

Lifetime checks track resource identities, copy parents, liveness and
exactly-once destruction. They keep owners alive through their last observation
and do not impose lexical lifetimes or one destructor order where native
lifetimes legitimately differ.

## Boundary controls

Matching is tested at its limits: a match with sixteen clauses, values a million
levels deep, a chain of a thousand `Next` steps, and shared values whose
expansion as a tree would have 2^61 leaves. Every admission rule has a
compile-failure fixture, paired with a valid program that differs from it in one
clause.

## Runner guarantees

`scripts/fp_tools` reserves a fresh output directory for every run, gives each
executable a unique path, bounds every command in time and memory, and serializes
a report. A compiler crash or timeout is always a failure, including for an
expected rejection. The runner hashes every input file (sources, tests, scripts,
documentation, benchmarks, `README.md`, `pixi.toml`, `pixi.lock`, `mkdocs.yml`)
and fails the run if any of them changes before it completes. The suite's report
keeps its generated drivers, executables and raw build and run logs; its audit
regenerates the drivers and re-derives every program's outcome from the logs
instead of trusting the reported flags.

## Definition of done

A capability is complete when:

1. its relationship to Mojo's native capabilities is recorded, with the gap it
   fills and its replacement trigger;
2. its API compiles on the pinned compiler through both import routes;
3. positive and compile-failure tests exist;
4. its ownership, evaluation-order and error behavior is documented in its
   reference chapter;
5. every performance or target claim has the corresponding measurement.

Compiler limitations and regressions are documented, not hidden behind claims of
zero cost.

## Change control

Semantic changes, public API changes and compiler-support changes are decided
explicitly and documented before they are implemented. Adding a constructor to a
public closed type breaks exhaustive clients and is versioned as a breaking
change; a formerly exhaustive match is never turned into an unchecked one to
hide that. Each compiler upgrade reviews convergence with Mojo and deletes
library code that native features have made redundant.

The commands that run all of this are in the
[development guide](../contributing/development.md).
