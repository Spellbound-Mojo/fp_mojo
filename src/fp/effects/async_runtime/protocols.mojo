"""Extension contracts for cooperative leaves and scoped asynchronous bodies.

IO.lift runs a custom Machine as one step of an IO. Each poll returns promptly
with Step.ready or Step.pending. A terminal step
certifies that entered work and cleanup finished or transferred ownership into
the result. Fresh scoped loans end with each poll. External work retains its own
access rights and must drain before release; readiness alone is not memory
synchronization. Public Context is the canonical IOContext, including its clock.

`await_readable[E](fd)` and `await_writable[E](fd)` suspend a fiber in the
root's poller until a `RawFileDescriptor` the caller owns, open and
nonblocking, is ready; library authors build pipes, sockets or process I/O on
them.
"""
from fp.effects import IOContext
from fp.effects._async.kernel import Machine
from fp.effects._async.scopes import ScopedMachine, CleanupMachine
from fp.effects._async.kernel import Step, Wait
from fp._internal.waking import Signal
from fp.effects._async.descriptors import await_readable, await_writable

comptime Context[E: Movable & Deinitable] = IOContext[E]
"""The canonical execution context with cancellation and opaque clock access.

Parameters:
    E: The exact native domain error of the current machine.
"""
