# Performance and execution targets

This page gives the cost of each operation and the measurements behind it. The
library makes no general zero-overhead claim: every performance statement on
this site names the operation, the compiler, the optimization level and how it
was measured. The numbers here were taken on Mojo 1.1.0 (8189361e), Linux
x86-64, unless stated otherwise.

## Cost model

Costs below exclude work done inside user callbacks and source iterators.

| Operation | Time and callback work | Auxiliary storage |
|---|---|---|
| `pipe` with `k` stages | One call per reached stage | Live intermediates only; no intermediate collection |
| `flow` / `compose` construction | Proportional to the moved component state | The components, stored natively; no callable box |
| `partial` construction | One copy of each bound argument | The bound copies and the function |
| `partial` call | One copy of each bound argument, then one call | The per-call copies, destroyed after the call |
| Sequential fold | Linear in consumed elements | Constant bookkeeping plus accumulator, callback and source state |
| `scan_left` | Linear, plus one accumulator copy per snapshot | The accumulator and the next snapshot |
| `map`, `filter`, `filter_map` | Linear in inspected elements | Constant bookkeeping plus source and callback state |
| `flatten`, `flat_map` | Linear in outer advances and yielded inner elements | The current inner source and outer state |
| `fp.match` | One dispatch and the selected clause per distinct value evaluated, plus the clauses tried before it | A 32-byte frame per pending value and one result per evaluated child on a value stack; a result per shared value when the result is `Copyable` |
| `fp.rewrite` | As `fp.match` | Plus one new node for each rebuilt value |

Two caveats: a fold whose accumulator is a growing collection does not use
constant storage, and a `filter` over an infinite source whose predicate never
succeeds does not terminate.

## Allocation policy

- The minimal non-capturing, trivial-payload cases of composition, folds and
  constructor dispatch perform no heap allocation for the abstraction itself.
- Allocation that the semantics require is allowed and documented: captured
  state, bound-argument copies in `partial`, snapshot copies in `scan_left`,
  `collect_list`, `collect_results`, `fp.control.scan` outputs, `Node` values
  (one allocation each) and the matching loop's frames and slots.
- A match keeps its frames and pending results in standard `List` storage
  instead of the native stack. That is the price of its depth guarantee; the
  [matching contract](matching.md#execution) gives the measured cost.
- Hot paths in the algebra core avoid `Optional`/`Variant` storage for
  non-trivial types, which Mojo initializes and takes out of line, and use
  untagged `MaybeUninit` slots instead. A checked `Optional.take()` is not
  inlined.

## Run-time evidence

At O3 the following compile to the same instructions as the equivalent
hand-written code, checked by comparing `--emit asm` output:

- a call through `as_unary`;
- `partial(scale, 3, 7)(x)` and the same partial passed through
  `map[IdentityFamily]`, against `scale(3, 7, x)`;
- Reader, State, OptionalT, ResultT and Writer pipelines built from `map`,
  `flat_map`, `map2`, `ask`, `get` and `modify`.

The suite's [runtime benchmarks](../contributing/benchmarks.md#runtime-benchmarks)
time `Result` mapping and list traversal against hand-written loops on every run;
they currently take about 1.4× and 1.3× the native loop.

Benchmarks compare against straightforward native code with the same order,
ownership, copying and error behavior. A parallel reduction is not a fair
baseline for a sequential fold, nor a borrowing binder for a copying one.

## Compile-time cost

Compile time is a cost users pay on every cold build, so it is measured like run
time, from an empty cache ([measuring compile time](../contributing/benchmarks.md#measuring-compile-time)).
Small algebra and effects programs build in 3–6 seconds cold on Linux x86-64,
and each additional transformer layer adds about a tenth of a second.

What makes Mojo 1.1 compile slowly is the type-level program, not code
generation:

- associated types that reach through chains of other structs' aliases,
  conditional types, or `TypeList` tabulate/filter pipelines can take minutes to
  verify, especially when a precompiled package is imported, because the import
  verifies conformances symbolically with unknown parameters;
- a warm compile cache hides this completely, so every measurement uses an empty
  `MODULAR_CACHE_DIR`.

The library therefore keeps associated types to a struct's own parameters and
their immediate members, puts behavior in method bodies, and uses one concrete
struct per operation (see [algebra](algebra.md#why-the-core-is-shaped-this-way)).
A client using `partial` builds cold in about 3 seconds from source or from the
precompiled package.

### Mojo 1.2 boundary prototype

The isolated [boundary prototype](mojo12-redesign.md) was compared with the
current `nightly` API on October 25, 2026 using Mojo 1.2.0 (2016d0cd), Linux
x86-64 and an AMD EPYC 9V74 host. The container had a four-CPU quota and 16 GiB
of memory. Builds ran serially, at O3 with one compiler thread, `--Werror` and
a separate empty Mojo cache per build. No other qualification builds ran
during measurement.

Each API compiled and executed three equivalent programs three times. The
order alternated by round: current/prototype, prototype/current,
current/prototype. These source-import measurements include compilation and
linking; package-import build cost and large programs were not measured.

| Client | Current median seconds (range) | Prototype median seconds (range) | Median peak RSS, current / prototype |
|---|---|---|---|
| Ordinary chain and capture | 5.11 (4.96–5.59) | 4.64 (4.50–4.85) | 250.1 / 255.9 MiB |
| Typed errors | 4.98 (4.97–5.02) | 4.54 (4.45–4.90) | 240.7 / 245.3 MiB |
| Generic forwarding | 4.61 (4.53–4.80) | 4.33 (4.17–4.43) | 242.1 / 228.7 MiB |

All 18 builds and executions passed, with clean audits and unchanged inputs.
These small samples show no compilation-time increase for these clients; they
do not establish a general speedup or a runtime performance claim.

The programs are under `experiments/mojo12-boundary/baseline/` and `clients/`.
Reports are `.cache/mojo12-architecture/measure-{baseline,prototype}-{1,2,3}/report.json`.
After creating the prototype overlay, reproduce one pair of rounds with the
canonical measurement tool, using fresh output paths:

```sh
pixi run measure-compilation \
  experiments/mojo12-boundary/baseline/ordinary.mojo \
  experiments/mojo12-boundary/baseline/raising.mojo \
  experiments/mojo12-boundary/baseline/generic_forwarding.mojo \
  --include src --level 3 --threads 1 \
  --output .cache/mojo12-architecture/measure-baseline-1
pixi run measure-compilation \
  experiments/mojo12-boundary/clients/ordinary.mojo \
  experiments/mojo12-boundary/clients/raising.mojo \
  experiments/mojo12-boundary/clients/generic_forwarding.mojo \
  --include .cache/mojo12-architecture/review/library --level 3 --threads 1 \
  --output .cache/mojo12-architecture/measure-prototype-1
```

## Mojo 1.2 API-quality passes

The contract metadata, Result generator policy and native collection adapter
passes were compared at `1d90a02` and `09f1664` on October 26, 2026. The baseline
source copy was checked byte-for-byte against all 99 tracked Mojo files at its
commit. Both versions used Mojo 1.2.0 (2016d0cd), Linux x86-64, the same
four-CPU/16-GiB container and source imports. No other compiler jobs ran during
measurement.

Each case ran twice per version, in baseline/current then current/baseline
order. Every invocation used a separate empty Mojo cache, O3, two compiler
threads, `--Werror`, a 180-second timeout and a 4-GiB sampled process-tree RSS
limit. Successful examples also executed; rejection clients never executed.
The table gives observed ranges, not confidence intervals or speedup claims.

| Client | Before, seconds | After, seconds | After native-timer peak RSS, MiB |
|---|---:|---:|---:|
| Selected workflow | 7.42–7.69 | 7.47–8.70 | 299.2–311.0 |
| Reusable Capture context | 2.98–3.40 | 3.44–3.48 | 232.4–240.9 |
| Dictionary values | 4.43–4.86 | 4.27–5.15 | 247.7–262.4 |
| Reject consuming filter predicate | 0.53–0.59 | 0.49–0.63 | 119.8–120.7 |
| Reject wrong n-ary callback arity | 0.81–1.15 | 0.83–0.90 | 123.0–123.5 |
| Reject consuming callback for mutable Capture | 0.18–0.22 | 0.17–0.18 | 102.1–103.2 |

All 24 invocations passed with clean audits and unchanged inputs. The selected
negative clients use ordinary calls without callback-type hints. They do not
qualify the invalid legacy calls described in the
[diagnostic audit](native-boundaries.md#current-api-quality-audit).
The observed valid-build range remains approximately 3–9 seconds for these
examples; the sample is too small to establish unchanged compile cost, a
general regression or an improvement. Package imports and larger applications
were not measured in this comparison.

Reports are `.cache/quality/cold-{baseline,current}-{1,2}/report.json`.
Reproduce the current cases with a fresh output directory:

```sh
pixi run measure-compilation \
  docs/examples/selected_workflow.mojo \
  docs/examples/capture_context.mojo \
  docs/examples/dictionary_values.mojo \
  tests/compile_fail/context_filter_owned.mojo \
  tests/compile_fail/context_native_nary_arity.mojo \
  tests/compile_fail/capture_m_convention.mojo \
  --include src --level 3 --threads 2 \
  --output .cache/quality/cold-current-recheck
```

## Mojo 1.2 Capture qualification

The Capture signature change in `51e0ef4` was compared with `3bf6041` on
October 26, 2026, using Mojo 1.2.0 (2016d0cd), Linux x86-64 and an AMD EPYC
9V74 host. Each compilation used a fresh Mojo cache, two compiler threads,
`--Werror`, a 180-second timeout and a 4-GiB sampled process-tree RSS limit.
Builds ran serially without other Mojo jobs. These are single observations
per client and route, not medians or evidence of a general speedup.

| Client and import route | Before, seconds | After, seconds | After peak RSS, MiB |
|---|---:|---:|---:|
| Capture tutorial, source | 4.15 | 3.77 | 256.7 |
| Selected workflow, source | 7.63 | 7.33 | 306.8 |
| Capture tutorial, precompiled | 3.84 | 4.31 | 256.1 |
| Selected workflow, precompiled | 5.59 | 6.37 | 327.8 |

The new stored-pointer convention and ownership clients also passed through
source and precompiled imports at O0 and O3. Those eight cold builds took
4.05–11.16 seconds and 271.2–437.8 MiB native-timer peak RSS. The maximum
sampled process-tree RSS was 448.6 MiB; it is a separate measurement from the
native timer. All sixteen builds executed successfully with unchanged input
and library hashes.

The generated Capture module grew from 156,455 to 390,299 bytes and from 218
to 551 `run` declarations, including private argument-bundle methods. The
Context module remained byte-identical. The finite signatures come from one
shared descriptor; they retain the explicit two-positional-operand limit.
The measured clients remain within the verification budget. These results do
not justify weakening ownership or error admission to reduce the overload count.

Reports are under `.cache/roadmap/resource-accounting/qualification/`, in
`{baseline,current}-{source,package}-O3` and `native-{source,package}-O{0,3}`.
The compiler, target, commands, client hashes, library hashes and cache policy
are recorded in each report. Reproduce a current client with:

```sh
pixi run measure-compilation tests/runtime/test_capture_native_abi_register.mojo \
  --include src --level 0 --threads 2
```

Independent source and precompiled installations also passed sixteen clients:
the Capture tutorial, selected workflow, stored stateful pointers and move-only
Capture ownership, each at O0 and O3 through both delivery formats. Compilation
used copied artifacts and an empty working directory outside the checkout;
executables then checked their assertions or reviewed tutorial output.
The install report is `qualification/install/report.json` under the same
workspace folder. This establishes those Linux host clients, not macOS or GPU
qualification, and does not publish a release.

## SIMD

One algorithm serves scalar, SIMD and non-numeric operations: `fold_left` over
SIMD vectors with vector addition returns a vector accumulator. Lanes are never
reduced horizontally unless the callback does it explicitly, and a SIMD mask is
never collapsed into a branch decision. A combinator adds no host-only
allocation, logging, reflection, exceptions or runtime dispatch to a
specialization that passes through it.
