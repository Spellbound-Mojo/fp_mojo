# Benchmarks

Runtime benchmarks against hand-written loops live in `tests/benchmarks/` and
run with the [suite](development.md#verification-gates). Compile time is measured
one program at a time, from an empty cache.

## Measuring compile time

Compile time is a cost users pay on every cold build. Mojo 1.1 compiles slowly
when the type-level program is large, not when the generated code is: before
the algebra core was rewritten, constructing a single Reader value took about
three minutes to compile, and before the matching signatures spelled their
result and error types flat, importing the sixteen-clause overloads took five
minutes (see [algebra and effects](../architecture/algebra.md#why-the-core-is-shaped-this-way)
and [native boundaries](../architecture/native-boundaries.md#generic-code)).
Measure a change that touches generic signatures before and after.

```sh
pixi run measure-compilation docs/examples/algebra_core.mojo --level 3 --timeout 60
```

The script builds one executable with two compiler threads, a 4 GiB process-tree
memory limit and a fresh, task-owned `MODULAR_CACHE_DIR`, then runs it if the
build succeeded. The script prints the path of a report under `.cache/compilation/`
with the commands, diagnostics, timings and outcomes. A timeout prints
`passed=False`, exits with status 1 and does not run the program. The script
stops at the first failure, so measure slow programs one at a time. `--timeout`
accepts up to 180 seconds.

**Always measure cold.** The shared project cache keeps compiled parameter work: a
build that takes minutes from an empty cache can take seconds warm.

To invoke the compiler directly on Linux:

```sh
mkdir -p .cache/repros
cache=$(mktemp -d -p .cache repro-cache-XXXX)
MODULAR_CACHE_DIR=$cache timeout --kill-after=5s 60s pixi run mojo build -I src -j 2 -O3 --Werror \
  docs/examples/algebra_core.mojo -o .cache/repros/algebra_core \
  && .cache/repros/algebra_core
rm -rf "$cache"
```

Add `--mlir-timing --mlir-timing-display=list` to see which compiler passes take
the time.

## Runtime benchmarks

The programs in `tests/benchmarks/` run library code and equivalent hand-written
native loops on identical inputs, check that their results agree, and print one
line per measurement: `bench <name> native_ns=<median> library_ns=<median>
samples=<n>`, the medians of alternating paired samples. `pixi run suite` builds
them into its `integration` executable, runs them after every test, and prints
the table below its results. They are diagnostics: a slow benchmark never fails
the suite.

| Benchmark | Library side | Native side |
|---|---|---|
| `result_map` | `map[ResultFamily[Int]]` over a `Result` that fails every 64th step | A `Variant` branch |
| `list_traverse` | `traverse` of a 1024-element `List` into an Applicative-only Identity | A loop that appends |
| `match_balanced` | `fp.match` evaluating a 9,556-value expression tree | A recursive function |
| `match_chain` | `fp.match` evaluating a 10,000-deep left chain | A recursive function |
| `rewrite_balanced` | `fp.rewrite` negating every number of the same tree | A recursive function that rebuilds it |

On the Linux x86-64 host that runs the verification gates, `result_map` takes about 1.4× and
`list_traverse` about 1.3× the native loop. `match_balanced` takes about 3×
and `match_chain` about 1.2× the recursive function, and `rewrite_balanced`
about the same time. Its clauses do almost nothing, so the matching loop is all
that is measured: a hand-written explicit-stack loop takes about 2.4× and 0.9×
on the same values (see [matching execution](../architecture/matching.md#execution)). A benchmark program also runs alone:

```sh
pixi run mojo run -I src -O3 tests/benchmarks/bench_algebra.mojo
```

When reporting a benchmark, record the compiler build, optimization flags,
operating system and architecture, data sizes, warm-up policy, repetitions and
dispersion, and compare against native code with the same order, ownership,
copying and error behavior.
