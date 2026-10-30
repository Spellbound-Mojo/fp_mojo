"""Pure-Mojo async IO with Cats Effect vocabulary and structured cooperative execution.

This opt-in preview targets the pinned Mojo 1.2 Linux x86-64 toolchain. An
`IO[T, E]` describes asynchronous work producing T or failing with the exact
domain error E; it runs once, when a host drives it. Methods and Pipeline
compose IO values, and `Async[E]` is their family for tail_rec_m, traversal and
attempt. Long sequences run iteratively in constant native stack. Callbacks
stored in an IO must own their state. Native callbacks run on the host thread
and must return cooperatively. No detached work or GPU backend is provided.

Use protocols for custom leaf machines, lifted with IO.lift. Driver owns entered
roots linearly: request cancellation, continue polling, then finish. Checked
Duration and opaque Instant keep deadline arithmetic wide. Only reviewed names
and documented metadata are supported, not private layout or ABI.
"""
from fp.effects._async.engine import IO, Async, Fiber, RaceWinner, RacePairResult
from fp.effects._async.fibers import FiberInfo, FiberStatus
from fp.effects._async.io_resource import Resource
from fp.effects._async.coordination import Deferred, Queue, Semaphore
from fp.effects._async.host import Clock, Driver, run
from fp.effects._async.kernel import Progress, IORuntimeConfig
from fp._internal.time import Duration, Instant
from fp.effects._async.racing import RaceResult
from fp.effects._async.finalization import Poll
from fp.effects._async.callbacks import Completion
