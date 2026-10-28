"""How the library calls user code: callable protocols, receiver dispatch and native functions as values.

Every higher-order operation calls user code through these protocols. A
callable fixes its argument, result and error types in a contract trait, and
implements each receiver mode it supports as its own trait:

| Arity | Shared | Exclusive | Consuming |
|---|---|---|---|
| one owned argument | `Unary.call` | `MutableUnary.call_mut` | `OnceUnary.call_once` |
| two owned arguments | `Binary.call` | `MutableBinary.call_mut` | `OnceBinary.call_once` |
| no argument | `Thunk.call` | `MutableThunk.call_mut` | `OnceThunk.call_once` |

`call_once` calls a callable of any mode once, preferring the consuming mode;
`call_repeated` calls one that stays usable, and requires `RepeatableUnary`,
`RepeatableBinary` or `RepeatableThunk`. `as_unary` moves a native function or
closure into a `NativeUnary`. `BorrowCallable` and `BorrowOnceCallable` borrow
their argument instead of taking it, and `invoke_borrowed` and
`invoke_borrowed_once` call them. Errors keep their exact types. `Partial`,
`Composition`, `Flipped`, `Tupled`, `MappedPair` and `Identity` from `fp.functions` implement these
protocols.

`as_binary` stores a plain binary function or thin pointer in `NativeBinary`.
It preserves two owned argument types and the exact result and error types.
Named adapters can be reused by shared borrow in `zip_with`, `map_with_index`,
`scan_map` and `scan_left`. The factory does not infer capturing closures.
`BinarySignature[A, B, R, E].capture(closure)` selects the signature before
capturing a binary closure into the same adapter. Its error defaults to `Never`.

Where each consumer enters:

| Consumer | Accepts |
|---|---|
| `pipe`, `flow`, `compose` | Two to eight plain functions, or library stages; inferred two-stage calls also mix a plain function or stored thin pointer with one library stage directly. `pipe` borrows a shared stage; compositions own their stages. Capturing unary closures use `as_unary`. |
| `piped(...).then` | Plain functions, closures and `Unary` values, one per call, with no limit |
| `flip` | `Binary` values and plain functions with two or more parameters |
| Lazy `map`, `filter_map`, `flat_map`, `scan_left` | Native callbacks and shared or mutable library unary/binary values |
| `fori_loop`, `while_loop`, `scan` | Native callbacks and shared-receiver `Unary`/`Binary` values |
| `fori_loop_mut` | A named shared or mutable library binary body, borrowed exclusively; updated receiver state remains in the caller. |
| Iteration predicates, `while_loop` predicates | Native predicates and `BorrowCallable` |
| `Result` methods and folds | Native callbacks, `Unary`, `OnceUnary`, `BorrowCallable` and `BorrowOnceCallable` |
| `attempt_once` | `OnceThunk` |
| `fp.match` and `fp.rewrite` clauses | Plain functions and lambdas without captures, taking one to three parameters |
| `fp.algebra`, `fp.effects` | Native functions and closures for `map`, `flat_map`, `traverse`, `modify`, `censor` and `local`; `Unary`, `Binary`, `Thunk` in any receiver mode; `BorrowCallable` for Reader's `local` and `action`, which also takes `BorrowOnceCallable` |

Lazy iteration callbacks are non-raising, because the native iterator protocol
raises only `StopIteration`; terminal callbacks keep their own error channel.
"""

from .protocols import (
    UnaryContract, Unary, MutableUnary, OnceUnary,
    BinaryContract, Binary, MutableBinary, OnceBinary,
    ThunkContract, Thunk, MutableThunk, OnceThunk,
    BorrowCallContract, BorrowCallable, BorrowOnceCallable,
)
from .invoke import (
    call_once, call_repeated, RepeatableUnary, RepeatableBinary, RepeatableThunk,
    BorrowCallCompatible, invoke_borrowed, invoke_borrowed_once,
)
from .native import NativeUnary, as_unary, NativeBinary, as_binary, BinarySignature
