"""Reader, State and Writer computations and the OptionalT and ResultT layers, over any base Monad.

| Family | Value | Additional operations |
|---|---|---|
| `ReaderT[M, R]` | A `ReaderAction`: borrows `R` when run, returns `M`'s carrier | `action`, `run`, `lift`, `ask`, `asks`, `local` |
| `StateT[M, S]` | A `StateAction`: consumes `S` when run, returns `M`'s carrier of `(A, S)` | `action`, `run`, `run_value`, `run_state`, `lift`, `get`, `inspect`, `put`, `modify` |
| `WriterT[M, W]` | A `WriterValue` wrapping `M`'s carrier of `(W.Value, A)` | `writer`, `run`, `run_value`, `run_log`, `lift`, `tell`, `listen`, `censor` |
| `OptionalT[M]` | `M`'s carrier of `Optional[A]` | `lift` |
| `ResultT[M, E]` | `M`'s carrier of `Result[A, E]` | `lift` |

`Reader[R]`, `State[S]` and `Writer[W]` are the transformers over
`IdentityFamily`; `OptionalT` and `ResultT` over Identity are `OptionalFamily`
and `ResultFamily[E]` themselves. Each family is a `Monad` of `fp.algebra`, so
`map`, `pure`, `flat_map`, `map2_lazy` and `traverse` apply to its values.
Reader and State values are deferred computations: nothing runs until `run`.

Ask/Local and Stateful are compile-time capability dictionaries. Reader and
State select their own environment or state; LiftAsk, LiftLocal and
LiftStateful explicitly select a capability from the immediate base. Generic
programs use the selected dictionary's Family for algebra operations.
Tell/Listen/Censor select a log; LiftTell, LiftListen and LiftCensor transport
those operations through one layer. Listen pairs the payload with an observed
log, while censor transforms only the selected computation's output log.

Transformer order matters. `StateT` over `Result` returns no state on failure;
`ResultT` over `State` can return a failed `Result` together with the updated
state. Neither rolls back external mutation. For `ResultT[State[S], E]`, run
with `run[State[S]]`, whose result is `Tuple[Result[A, E], S]`, and lift
State's operations into the ResultT layer; for `StateT[ResultFamily[E], S]`,
run with that StateT, whose result is `Result[Tuple[A, S], E]`.

| Stack | Evaluation order | Final shape |
|---|---|---|
| `WriterT[Reader[R], W]` | Writer `run`, then Reader `run` | `(log, value)` |
| `ReaderT[Writer[W], R]` | Reader `run`, then Writer `run` | `(log, value)` |
| `WriterT[State[S], W]` | Writer `run`, then State `run` | `((log, value), state)` |
| `StateT[Writer[W], S]` | State `run`, then Writer `run` | `(log, (value, state))` |

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

Resource owns native scopes; IOResource composes effectful acquisition, use
and outcome-aware release through the same lifecycle. IO uses the existing
Reader, Result and Optional families for typed outcomes and cooperative
cancellation. Ref, Deferred, Semaphore and Queue construct IO recipes over
shared state. The optional Fiber backend requires explicit unsafe_start and
its documented thread-safety obligations.
"""
from .protocols import Project, Ask, Local, Stateful, Tell, Listen, Censor, ReaderAction, StateAction, ReaderFamily, StateFamily, WriterFamily
from .reader import ReaderT, Reader
from .capabilities import LiftAsk, LiftLocal, LiftStateful, LiftTell, LiftListen, LiftCensor, TellContract, ask, local, get, put, modify, tell, listen, censor
from .state import StateT, State
from .writer import WriterT, Writer, WriterValue, writer, run_writer
from .layers import OptionalT, ResultT
from .operations import run, run_value, run_state, run_log, RunValueContract, RunStateContract, WriterValueContract, WriterLogContract, action, lift
from .projections import LiftProject, asks, inspect
from .outcomes import EffectFailure, Outcome, ExitCase, FoldOutcomeContract, fold_outcome
from .resources import Resource, ResourceContract, resource, pure_resource
from .io import IO, IOContract, IOContext, CancellationToken, delay, run_io, capture_io, guarantee, uncancelable, canceled, sleep_io, use_resource
from .fibers import Fiber, unsafe_start
from .coordination import Ref, Deferred, Semaphore, Permit, Queue

from .scoped import ScopedIO, scoped_io
from .finalization import GuaranteeCaseContract, guarantee_case, on_cancel, Poll, uncancelable_with
from ._io_core import DelayContract

from .effectful_resources import IOResource, IOResourceContract, IOResourceCaseContract, IOResourceFullContract, resource_io, resource_io_case, resource_io_full, resource_io_case_full, eval_resource, lift_resource
