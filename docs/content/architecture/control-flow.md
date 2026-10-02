# Control flow

`fp.control` provides `while_loop`, `fori_loop` and a carry/output `scan`,
following the sequential value semantics of JAX's
[`lax` control-flow operations](https://docs.jax.dev/en/latest/jax.lax.html).
They are ordinary compiled Mojo loops: there is no tracer, tensor
type, pytree registry, automatic array stacking, autodiff, batching or JIT.

## Relationship to other packages

- `fp.data` owns `ControlFlow`, `Break` and `Continue`, the early-termination
  values used by `fold_until`. `fp.control` does not use them for loops.
- `fp.iteration.scan_left` is a lazy snapshot scan: it yields the initial
  accumulator and a copy after each step. `fp.control.scan` is eager, does not
  emit the initial carry, returns separate carry and output values, and never
  copies either.
- There is no function-valued branch: with closures, JAX's `cond` is an
  ordinary `if`.

## Contracts

| Operation | Contract |
|---|---|
| `while_loop(cond_fun, body_fun, init_val)` | Borrows the carry for the predicate before every iteration and moves it into the body only when the predicate is true. The body returns exactly the carry type. A false first test returns the initial value without calling the body. |
| `fori_loop(lower, upper, body_fun, init_val)` | Calls `body(index, carry)` for ascending unit indices in `[lower, upper)`. Equal or reversed bounds make no calls. The trip count is never computed as `upper - lower`, so extreme bounds cannot overflow. |
| `scan(f, init, xs, length=..., reverse=...)` | Calls `f(carry, element)`, which returns `(next_carry, output)`, and returns `(final_carry, List[output])`. Carry and output types may differ and need not be copyable. With `reverse=True` the calls run from the last input, and each output still lands at its input's position. |

`scan` accepts an owned `List` or a finite native iterator, which is collected
eagerly with `collect_list` before any callback runs. That makes exact length
validation and reverse traversal possible, and it means all input pulls happen
before the first callback. A supplied `length` must equal the whole input size; it
never truncates. Without inputs, `length` or `static_length` is required and each
call receives the empty product `Tuple[]`.

## Callbacks

Loop callbacks are called repeatedly, so they keep one receiver for the whole
loop and are never copied or rebuilt per iteration; consuming-only receivers are
rejected. Native functions and closures have direct pure and raising overloads.
Library bodies are shared-receiver `Unary` or `Binary` values, such as partials
and compositions, and `while_loop` predicates may be `BorrowCallable` values.

## Errors

Predicate and body errors stop the loop at once. They must be `Never` or one
common native type, including embedded origins. Nothing retries, rolls back
effects or copies a carry.

`scan` separates its own validation from callback failure. An invalid or missing
length raises `ScanLengthError` (with `expected` and `actual`, where `actual=-1`
means no length was given) before any callback. A raising callback's error is
kept intact inside `ScanStepError[E]`, and the scan raises `ScanError[E]`, the
native `Variant` of the two. A callback's `StopIteration` is a step error, not
exhaustion. Pure callbacks raise only `ScanLengthError`.

## Unrolling

`unroll` is a compile-time parameter. The default `1` runs a rolled loop. A
larger value expands that many steps per chunk, with an exact bounds check for the
final partial chunk; order and error behavior are unchanged. `unroll=0` expands the
whole loop and therefore needs static bounds: `fori_loop[lower, upper, unroll=0]`
or `scan[static_length=N, unroll=0]`. Negative factors, full unrolling without
static bounds and inconsistent static lengths are compile errors. `while_loop`
has no `unroll` because its trip count depends on data.

The scan step is compiled behind a non-inlining boundary. Without it, Mojo 1.1
crashes at O3 on callbacks that always raise.

## Implementation

`fp.callables` owns the receiver dispatch and `_internal.errors` the error
identity. One indexed kernel serves both `fori_loop` and scan's carry/output
accumulation; one kernel sequences the predicate and body of `while_loop`. Native
callback overloads reuse the unary, binary and predicate bridges from
`fp.iteration`.
