"""Functional loops and scans over native Mojo values: `while_loop`, `fori_loop` and `scan`.

They follow the sequential value semantics of JAX's control-flow operations,
without tensor stacking, tracing, autodiff or a JIT. Branch with Mojo's `if`.

The carry may be any value: a scalar, a SIMD value, a string, a container or a
move-only owner. Its type stays fixed, and nothing copies it. A callback is a
plain function or a closure, with separate pure and raising overloads, or a
shared-receiver library value: `Unary` for a `while_loop` body, `Binary` taking
`(Int, carry)` for a `fori_loop` body, and a `Binary` step for `scan`, whose
output type is then named, `scan[Y](step, ...)`. A `while_loop` predicate may
be a `BorrowCallable`. A call needing keywords or defaults is written as a
closure. Callbacks keep one receiver throughout.

Errors stop the loop at once. A predicate and a body must raise one error type,
including any embedded origins, or one of them nothing. Nothing retries or
rolls back effects.

The compile-time parameter `unroll` expands that many steps per rolled
iteration, with exact bounds checks for the final partial chunk; `1`, the
default, keeps a rolled loop. `unroll=0` fully expands a statically bounded
loop: `fori_loop[lower, upper, unroll=0](body, initial)` or
`scan[static_length=N, unroll=0](...)`. Full unrolling without static bounds,
a negative factor and an invalid static length are compile errors.
`while_loop` has no unroll parameter.
"""
from .loops import while_loop, fori_loop
from .scan import scan, ScanLengthError, ScanStepError, ScanError
