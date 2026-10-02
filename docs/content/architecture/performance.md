# Performance and execution targets

Efficiency is a design requirement, but the library makes no universal
zero-overhead claim. Every performance statement on this site names the
operation, the compiler, the optimization level and how it was measured. The
numbers here were taken on Mojo 1.1.0 (8189361e), Linux x86-64, unless stated
otherwise.

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
| Visitor | One selected handler | No allocation for dispatch |
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

## SIMD

One algorithm serves scalar, SIMD and non-numeric operations: `fold_left` over
SIMD vectors with vector addition returns a vector accumulator. Lanes are never
reduced horizontally unless the callback does it explicitly, and a SIMD mask is
never collapsed into a branch decision. A combinator adds no host-only
allocation, logging, reflection, exceptions or runtime dispatch to a
specialization that passes through it.

## GPU and other targets

The library respects the surrounding execution context and never chooses one. It
does not launch kernels, transfer inputs, synchronize streams, infer address
spaces or assume a device-resident handle is readable on the host. If a callback
returns an asynchronous handle, composition treats the handle as an ordinary
result; waiting is the caller's job.

The device-compatible subset is the non-raising, allocation-free core over
device-passable values: invocation, composition, `partial` with device-passable
bound values, sequential device-local folds, and `Result` and constructor
dispatch. Host-owned lists, strings, dynamically allocated recursive structures
and exception bridges are not device-portable. The
[device example](../examples/device.md) compiles this subset for GPU targets;
no execution on GPU hardware has been verified yet (see
[support and limitations](../guides/status.md)).

A parallel reduction would be a separate API from sequential `reduce`, with its
own identity, associativity, ordering and nondeterminism contract. Floating-point
results are not promised to be bitwise identical across reduction orders or
targets.
