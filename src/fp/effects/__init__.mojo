"""Reader, State and Writer computations and the OptionalT and ResultT layers, over any base Monad.

| Family | Value | Additional operations |
|---|---|---|
| `ReaderT[M, R]` | A `ReaderAction`: borrows `R` when run, returns `M`'s carrier | `action`, `run`, `lift`, `ask`, `local` |
| `StateT[M, S]` | A `StateAction`: consumes `S` when run, returns `M`'s carrier of `(A, S)` | `action`, `run`, `lift`, `get`, `put`, `modify` |
| `WriterT[M, W]` | A `WriterValue` wrapping `M`'s carrier of `(W.Value, A)` | `writer`, `run_writer`, `lift`, `tell`, `listen`, `censor` |
| `OptionalT[M]` | `M`'s carrier of `Optional[A]` | `lift` |
| `ResultT[M, E]` | `M`'s carrier of `Result[A, E]` | `lift` |

`Reader[R]`, `State[S]` and `Writer[W]` are the transformers over
`IdentityFamily`; `OptionalT` and `ResultT` over Identity are `OptionalFamily`
and `ResultFamily[E]` themselves. Each family is a `Monad` of `fp.algebra`, so
`map`, `pure`, `flat_map`, `map2_lazy` and `traverse` apply to its values.
Reader and State values are deferred computations: nothing runs until `run`.

Transformer order matters. `StateT` over `Result` returns no state on failure;
`ResultT` over `State` can return a failed `Result` together with the updated
state. Neither rolls back external mutation. For `ResultT[State[S], E]`, run
with `run[State[S]]`, whose result is `Tuple[Result[A, E], S]`, and lift
State's operations into the ResultT layer; for `StateT[ResultFamily[E], S]`,
run with that StateT, whose result is `Result[Tuple[A, S], E]`.

| Stack | Evaluation order | Final shape |
|---|---|---|
| `WriterT[Reader[R], W]` | `run_writer`, then Reader `run` | `(log, value)` |
| `ReaderT[Writer[W], R]` | Reader `run`, then `run_writer` | `(log, value)` |
| `WriterT[State[S], W]` | `run_writer`, then State `run` | `((log, value), state)` |
| `StateT[Writer[W], S]` | State `run`, then `run_writer` | `(log, (value, state))` |

`OptionalT[ResultT[M, E]]` carries `M[Result[Optional[A], E]]`, and
`ResultT[OptionalT[M], E]` carries `M[Optional[Result[A, E]]]`. Either an
absence or a stored error skips later callbacks and lazy right operands,
without converting one failure kind into the other. Native exceptions from any
stage propagate with their exact types instead of becoming `Result` data.

Traversal into a layer delegates to the base's traversal loop with the layer's
accumulation rule, so the count of pulls and callback calls is the same over
eager, deferred and third-party bases. A deferred computation can be copied or
replayed only when its stored inputs and callbacks support it; copying an owner
does not make a consuming callback reusable.
"""
from .protocols import ReaderAction, StateAction
from .reader import ReaderT, Reader, ask, local
from .state import StateT, State, get, put, modify
from .writer import WriterT, Writer, WriterValue, writer, run_writer, tell, listen, censor
from .layers import OptionalT, ResultT
from .operations import run, action, lift
