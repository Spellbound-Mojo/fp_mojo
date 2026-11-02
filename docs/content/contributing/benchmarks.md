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

The memory budget samples the compiler process and its descendants: on Linux
from `/proc` parent IDs, which include children launched by other threads and
work when the mount omits `task/*/children`, and on macOS from one
`ps -axo pid=,ppid=,rss=` snapshot per sample. Exceeding the sampled budget
terminates the command's process group. RSS samples are not an atomic measure
of unique physical memory: shared pages can appear in several processes, and
brief peaks can occur between samples. The report separately retains the native
timer's peak RSS. Older reports on mounts without child lists retained that
timer measurement but could undercount the sampled process tree.

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
| `node_build` | Building a complete binary `Node` tree of 262,143 values | The same tree of hand-written `ArcPointer` cells |
| `node_traverse` | Summing the `Node` tree by recursion | Summing the `ArcPointer` tree by recursion |
| `node_drop` | Releasing the `Node` tree | Releasing the `ArcPointer` tree through its destructors |
| `match_large` | `fp.match` summing the `Node` tree | Recursion over the same `Node` tree |
| `node_revisions` | 32 path-copy edits of a 65,535-value `Node` tree, keeping the last 8 revisions and summing each with `fp.match` | The same edits and sums on the `ArcPointer` tree |

On the Linux x86-64 host that runs the verification gates, `result_map` takes about 1.4× and
`list_traverse` about 1.3× the native loop. `match_balanced` takes about 4×
and `match_chain` about 3.5× the recursive function, and `rewrite_balanced`
about 1.1×. Their clauses do almost nothing, so the matching loop is all that is
measured (see [matching execution](../architecture/matching.md#execution)).

The `node_*` benchmarks compare `Node` storage with what a program would write
without the library. Their trees are larger than the caches, so traversal is
bound by memory traffic and varies by tens of percent between runs on a shared
host. On Mojo 1.2.0 in a 4-CPU Linux x86-64 container, across three runs,
`node_build` took about 0.68×, `node_traverse` about 0.39× and `node_drop`
about 0.5× the `ArcPointer` tree, `match_large` about 2.7× the recursion, and
`node_revisions` about 0.8×. Before values were stored in compact cells, these
benchmarks measured 1.02–1.06×, 0.75–0.94×, 0.8–1.0×, 1.9–2.3× and 1.7–1.9×
(`experiments/node-storage` keeps the comparison).
A benchmark program also runs alone:

```sh
pixi run mojo run -I src -O3 tests/benchmarks/bench_algebra.mojo
```

When reporting a benchmark, record the compiler build, optimization flags,
operating system and architecture, data sizes, warm-up policy, repetitions and
dispersion, and compare against native code with the same order, ownership,
copying and error behavior.
