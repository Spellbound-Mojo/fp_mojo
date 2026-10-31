# Development

Use this guide to set up the development environment, choose verification
commands and work with the pinned Mojo compiler. Start with the
[design principles](../architecture/principles.md), which define the library's
scope and the ownership of shared mechanisms.

## Environment

Set up the environment as in [installation](../start/installation.md). The
tooling scripts call `pixi` and `mojo` from `PATH`, so make sure
`$HOME/.pixi/bin` is on it. The compile-time measurement and its tooling test use
GNU `time` (`/usr/bin/time`, or `time` on `PATH` when that path is absent);
on Debian or Ubuntu install it with
`apt-get install time`.

Mojo shares one compile cache per environment under
`.pixi/envs/default/share/max/cache`. A warm cache hides most compile-time cost,
so measure compile time only with an empty `MODULAR_CACHE_DIR` (the measurement
tooling does this for you).

## Repository layout

| Path | Contents |
|---|---|
| `src/fp/` | The library, one directory per public package plus `_internal` |
| `tests/runtime/`, `ownership/`, `laws/`, `integration/` | Programs with a `main` that assert their results |
| `tests/benchmarks/` | Programs that time library code against hand-written loops; the suite reports them as diagnostics |
| `tests/compile_fail/` | Programs that must be rejected, with `# error:` lines naming the expected diagnostics |
| `tests/tooling/` | Python unit tests for the scripts |
| `scripts/` | Test, build, measurement and documentation tooling, and the generator of plain-function `pipe`, `flow`, `compose`, `match` and `rewrite` overloads (`python scripts/generate_plain_overloads.py`; `--check` reports drift). Capture and selected Pipeline signatures use `generate_capture.py` and `generate_context.py`; tooling tests check their generated output |
| `docs/content/` | This site's pages; navigation is in `mkdocs.yml` |
| `docs/examples/` | The runnable examples |
| `docs/theme/` | The MkDocs theme: templates, styles, scripts and bundled fonts |
| `docs/*.json`, `docs/hooks.py` | Public export inventory, API descriptions, example outputs and the MkDocs hooks |

## Verification gates

Run from the repository root. Commands with `--output` need a directory that
does not exist yet; use a new name under `.cache/` each time.

| Command | Checks | Compilation workload |
|---|---|---|
| `pixi run suite --package .cache/b2` | Runtime, ownership, law and integration tests, reviewed example output and benchmark diagnostics at O3 | Four executables; `--jobs` limits concurrent builds |
| `pixi run compile-fail --package .cache/b2` | Every rejection fixture produces its declared diagnostics | One compile per fixture; `--jobs` limits concurrency |
| `pixi run build --output .cache/b1` | Builds a source package in `<output>/fp/`, precompiles with `--Werror`, then runs `docs/examples/algebra_core.mojo` against it | Package precompile and a bounded client build/run |
| `pixi run build --format precompiled --output .cache/b2` | The same with `fp.mojoc` | Package precompile and a bounded client build/run |
| `pixi run -e docs docs-check` | Strict MkDocs build, then links, anchors, assets and the search index | No Mojo compilation |
| `pixi run boundaries-test --output .cache/native-admission --jobs 4` | Capture and selected Pipeline tests, including rejection diagnostics and lifetime controls | Fresh package, then source/package builds at O0/O3 per fixture |
| `pixi run docs-test --output .cache/d1 --jobs 4` | Every example prints its reviewed output with `--Werror` | Fresh package, then four builds and runs per example |
| `pixi run python -m unittest discover -s tests/tooling` | Tooling unit tests | Python checks, including bounded subprocess/resource controls |

Choose concurrency from the available memory as well as the CPU count. The
suite builds large groups of programs, while rejection and example runners
compile separate clients; the same `--jobs` setting does not imply the same
memory use. Elapsed time also depends on the selected fixtures, optimization,
compiler cache and competing work. Use retained build/run timings to estimate
the next comparable run; benchmark diagnostics collected under shared load do
not establish a performance regression.

The opt-in [async overnight qualification](../architecture/async-qualification.md)
has its own bounded runner and evidence audit. Run it from an immutable checkout;
its default twelve one-hour cases take approximately six hours with two workers,
plus compilation and separate serial performance measurements. It is not part of
the routine suite, and short calibrations do not qualify as overnight results.

`suite` and `compile-fail` test the library a `build` produced: pass its output
directory to `--package`. `--source` compiles against `src/` instead, and with
neither option they precompile `src/fp` into their own output folder first.
`--optimization 0` builds at O0 instead of O3; the suite's O0 executables take
several times longer to build and up to about 5 GB each, so pass `--jobs 2` on a
16 GB machine. `--filter <text>` selects the programs whose path contains the text, and
`--output <dir>` names the report folder (a fresh one under `.cache/` by
default). `build` defaults to a 60-second limit for each package and client compilation,
with two compiler threads and a 4 GiB memory limit on Linux. Select a longer
recorded budget with `--compile-timeout 180` when a larger package exceeds that
limit. A timeout remains a failed run; retain it and use a fresh output directory
for the new budget.
The Linux resource test checks the whole timed process group. It accepts a killed
child reaped by the timer or by the test's subreaper, while requiring that the
child is gone. Reaping ownership is a scheduling detail, not the memory-limit
contract. The correction passed 20 repeated runs of the resource checks.

The suite keeps every program standalone: each still has its own `main` and can
be run alone with `pixi run mojo run -I src <path>`. `scripts/suite.py`
generates one driver per executable that imports the programs as top-level
modules and calls each `main` between marker lines, builds the four
executables in parallel into one directory (`--jobs` limits how many build at
once; each needs up to about 3 GB), then runs them in sequence:

| Executable | Programs |
|---|---|
| `runtime-1` | `tests/runtime/test_[a-c]*` |
| `runtime-2` | The rest of `tests/runtime/` |
| `ownership` | `tests/ownership/` |
| `integration` | `tests/integration/`, `tests/laws/`, the examples in `docs/examples.json`, then `tests/benchmarks/` |

A failing assertion fails only its program. A crash or timeout fails the
program that was running, and the executable restarts after it (`--from N`). An
example passes only when it prints its reviewed output. Benchmark lines are
reported as diagnostics and never fail the suite. The report in the output folder
keeps the generated drivers, the build and run logs and the executables, and an
independent audit re-derives every outcome from the raw logs.

Programs built into one executable must not spell the same function type over
different declarations that share a name: Mojo 1.1 treats them as one type and
the build fails with `invalid redefinition of 'def(...)'` (see
[native boundaries](../architecture/native-boundaries.md#known-compiler-defects)).
Give a test-local type a name specific to its test, such as `PipelineFailure`
rather than `Failure`, when the build reports it. Each executable resolves its
programs by module name, so file names must be unique across its directories;
the suite checks this before building.

Rules that matter:

- **Do not edit inputs while `suite`, `compile-fail` or `docs-test` runs.** They hash `src/`,
  `tests/`, `scripts/`, `docs/`, `benchmarks/`, `README.md`, `pixi.toml`,
  `pixi.lock` and `mkdocs.yml`, and fail if anything changes before they finish.
- **Precompile after changing traits or generic signatures.** A package
  precompile type-checks generic declarations that no client instantiates;
  several Mojo 1.1 trait errors appear only there.
- **Interrupted runs are incomplete evidence.** Keep their partial logs, then
  start the interrupted gate in a fresh output directory. Individual successful
  compiles do not replace its final report and audit. Reuse a completed gate only
  after checking its recorded inputs against the current tree and its package
  digest against the package being used. See the
  [runner guarantees](../architecture/verification.md#runner-guarantees).
- **Stopping a run.** `pkill -f "<pattern>"` also matches your own shell if the
  pattern appears in its command line. Use a bracketed pattern such as
  `pkill -f "scripts/[s]uite.py"`, and stop orphaned `mojo build` children too.

The local documentation audit also checks `docs/compatibility.json` against the
reviewed public export inventory. New Pipeline methods must have a family,
callback, ownership, error and evaluation contract; completed migration names
move out of the pending assignment. Qualification checkpoints name the tested
source commit and retain report digests. Update them only from completed gates.

## Making a change

1. **Design the whole contract first.** State ownership, evaluation order, errors,
   empty and no-match behavior, and costs before editing. A restricted example
   that works does not complete a feature.
2. **Find the owner.** Every shared mechanism has one implementation (see the
   [overview](../architecture/overview.md#shared-mechanisms)). Reuse or
   generalize it and migrate every consumer; never add a parallel version.
3. **Name API changes explicitly.** Public API or behavior changes are decided
   before they are implemented and documented with a migration.
4. **Test both ways.** Add positive programs and compile-failure programs for the
   new rejections. Keep expected values independent of the operation under test,
   pair each rejection with a nearby valid program, and never execute a program
   the compiler was expected to reject. A compiler crash or timeout is a failure,
   never a passing rejection.
5. **Run the suite and the compile-failure fixtures** against a fresh package
   build, and `docs-check` and `docs-test` if pages or examples changed.
   `docs-test` also covers the source route and O0.
6. **Update the documentation** in the same change (see
   [maintaining the docs](documentation.md)).

## Working with the pinned compiler

These practices were established on Mojo 1.1 and retained for the Mojo 1.2
migration. The limits and compatibility changes are recorded in
[native Mojo boundaries](../architecture/native-boundaries.md).

- **Keep the type-level program small.** Associated types should name only a
  struct's own parameters and their immediate members; put behavior in method
  bodies; use one concrete struct per operation. Chains of conditional aliases
  and `TypeList` pipelines can take minutes to verify, especially through a
  precompiled package.
- **Diagnose compile time by bisection.** `--mlir-timing
  --mlir-timing-display=list` shows only the phase (`Import Mojo` is the front
  end). The compiler binary is stripped and attaching a debugger is blocked, so
  precompile package variants that each remove one declaration, build a tiny
  import-only client against each in parallel, and compare.
- **Report admission errors first.** The first failing inline `comptime assert`
  is reported before failures inside called helpers. Put admission checks inline
  and gate the callee with `comptime if admitted:` so its errors do not mask the
  admission message.
- **Infer a callback's error as `AnyType` before catching it.** Under a
  `Movable & Deinitable` bound, a non-raising function's inferred error is an
  uninhabited type that is not `Never`, and a `try` around a call that raises it
  crashes the compiler. Infer it as `AnyType` and normalize it with
  `_internal.errors._NativeError`, or call through `_forward`.
- **Do not nest calls to an overloaded function.** Overload resolution
  backtracks through nested calls, so compile time grows exponentially with the
  nesting depth; give each overload of a nested builder its own name.
- **Spell signature types flat.** A type derived through a chain of generic
  structs, such as a result computed from a list of clauses, can take compile
  time exponential in the chain's length when it appears in a signature. Spell
  it over the parameters directly and pass it to the implementation explicitly.
- **Check hot paths in assembly.** `Optional` and `Variant` storage of
  non-trivial types is initialized and taken out of line, and `Optional.take()`
  is not inlined; use untagged `MaybeUninit` slots where it matters. Compare O3
  `--emit asm` output against hand-written code.
- **Measure against a hand-written version, then count instructions.** Write the
  same computation by hand in the shape the library uses (a loop with an
  explicit stack, say) to separate the cost of the shape from the cost of the
  library. Count instructions with `valgrind --tool=callgrind` on a build with
  `-g --target-cpu x86-64-v3` (valgrind cannot run AVX-512 instructions), and
  give `callgrind_annotate --include` the standard-library checkout to see its
  lines. Wall times on a shared host vary by 2x over minutes, so only compare
  runs taken back to back.
- **Inline small helpers on hot paths.** The pinned compiler can leave a small
  generic helper out of line; `@always_inline` on the matching engine's
  per-value helpers halved its time. Keep per-element state small: a 64-byte
  frame instead of a 16-byte one doubled the time of a hand-written loop over a
  deep value.
- **Never pass an iterator source through `iter()`** inside the library: it
  restarts sources that are both iterator and iterable. Take sources through
  `iteration._advance._source`, which uses an iterator as it is and consumes
  only an owned collection.
- **Test heap contents.** A `String`'s `byte_length()` reads inline metadata and
  can look correct for a dangling buffer; compare contents.
- **Read the pinned standard library.** Clone
  `https://github.com/modular/modular` at branch `mojo/v1.2.0` and read
  `Mojo/stdlib/std`; `mojo doc` cannot read the compiled `std.mojoc`.
