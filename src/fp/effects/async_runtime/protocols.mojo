"""Extension contracts for cooperative leaves and scoped asynchronous bodies.

IO.lift runs a custom Machine as one step of an IO. Each poll returns promptly
with Step.ready or Step.pending. A terminal step
certifies that entered work and cleanup finished or transferred ownership into
the result. Fresh scoped loans end with each poll. External work retains its own
access rights and must drain before release; readiness alone is not memory
synchronization. Public Context is the canonical IOContext, including its clock.
"""
from fp.effects import IOContext
from fp.effects._async.kernel import Machine
from fp.effects._async.scopes import ScopedMachine, CleanupMachine
from fp.effects._async.kernel import Step, Wait
from fp._internal.waking import Signal

comptime Context[E: Movable & Deinitable] = IOContext[E]
"""The canonical execution context with cancellation and opaque clock access.

Parameters:
    E: The exact native domain error of the current machine.
"""
