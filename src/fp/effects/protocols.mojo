"""Effect computations and the family capabilities they share.

A computation is a concrete struct that knows how to run itself. Its associated
types name only its own parameters and those of its direct children, so a
composed computation's type is the tree of its operations. Reader results may
retain the borrowed environment, so their types take the environment origin.
A Writer value wraps its base carrier; OptionalT/ResultT values are base
carriers.
"""
from std.builtin.rebind import downcast
from fp.algebra.protocols import Monad, Monoid, _Lifting, _FamilyCarrier
from fp.callables.protocols import BorrowCallContract, UnaryContract, ThunkContract
from fp._internal.time import Duration


trait Project:
    """Borrow a selected environment or state without copying the whole value.

    The projection returns an owned result and leaves the selected input
    unchanged. Its result and error cannot borrow the temporary input of a
    run. Captured origins belonging to longer-lived owners remain intact.
    Reader and State implement this capability independently of ask/get,
    which require copying. LiftProject selects a capability through a layer.
    """
    comptime Family: Monad
    """The family in which the projection operates."""
    comptime Input: AnyType
    """The exact selected environment or state type."""
    comptime ProjectCompatible[F: BorrowCallContract & Movable & Deinitable]: Bool
    """Whether F borrows Input and has an available invocation mode."""
    comptime Projected[F: BorrowCallContract & Movable & Deinitable]: Movable & Deinitable
    """The concrete family carrier of the projection's result."""
    comptime ProjectError[F: BorrowCallContract & Movable & Deinitable]: Movable & Deinitable
    """The exact construction error; deferred execution errors stay deferred."""

    @staticmethod
    def project[F: BorrowCallContract & Movable & Deinitable](var function: F
    ) raises Self.ProjectError[F] -> Self.Projected[F]:
        """Construct one borrowed projection in this family.

        Parameters:
            F: An admitted borrowing callback.

        Args:
            function: The projection, consumed.

        Returns:
            The family's carrier of F.Result, preserving execution timing.

        Raises:
            The exact native construction error.
        """
        ...


trait Ask:
    """Read an environment in a selected effect family.

    A capability is a compile-time dictionary, not a runtime carrier. Generic
    programs use `Family` for ordinary algebra operations. `ask` copies the
    environment; forward `AskAvailable` in generic function constraints.
    Implementations must return a Family carrier whose payload is Environment.
    """
    comptime Family: Monad
    """The family in which this capability operates."""
    comptime Environment: AnyType
    """The selected environment, including its native origins."""
    comptime AskAvailable: Bool
    """Whether this selection admits copying the environment."""
    comptime Asked: Movable & Deinitable
    """The concrete carrier returned by ask."""
    comptime AskError: Movable & Deinitable
    """The exact native error of constructing ask, separate from running it."""
    @staticmethod
    def ask() raises Self.AskError -> Self.Asked:
        """Construct an environment read, when AskAvailable holds.

        Returns:
            The selected family's environment carrier.

        Raises:
            The native construction error.
        """
        ...


trait Local(Ask):
    """Scope a selected environment without changing the surrounding one.

    The callback borrows Environment and returns an owned Environment. The
    scoped computation and callback are consumed. An identity scope preserves
    the result; nested scopes compose in execution order. This capability can
    scope move-only environments even when AskAvailable is false.
    """
    comptime LocalCompatible[V: Movable & Deinitable]: Bool
    """Whether V admits this scope, preserving its family and native origins."""
    comptime Localized[V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable]: Movable & Deinitable
    """The concrete scoped carrier; its payload is unchanged."""
    comptime LocalError[V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable]: Movable & Deinitable
    """The native construction error; deferred execution has its own error."""
    @staticmethod
    def local[V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.LocalError[V, F] -> Self.Localized[V, F]:
        """Construct a scope for an admitted carrier and environment callback.

        Parameters:
            V: A carrier satisfying LocalCompatible.
            F: A borrowing callback with Payload and Result equal to Environment.

        Args:
            f: The environment transformation, consumed.
            value: The computation to scope, consumed.

        Returns:
            A carrier of Family with the original payload type.

        Raises:
            The native construction error.
        """
        ...


trait Stateful:
    """Read and update a selected state in an effect family.

    This compile-time dictionary selects one state, including when a stack has
    several states of the same type. Reading copies the state; modification
    consumes it and returns its replacement. Move-only state supports updates
    without supporting get. Implementations preserve the ordinary state laws:
    get leaves state unchanged, the last put wins, and modifications compose
    in execution order. Native failures follow the selected family's semantics.
    """
    comptime Family: Monad
    """The family in which this capability operates."""
    comptime StateType: Movable & Deinitable
    """The selected state's exact type, including native origins."""
    comptime GetAvailable: Bool
    """Whether this selection admits copying the state."""
    comptime Got: Movable & Deinitable
    """The concrete carrier of StateType returned by get."""
    comptime GetError: Movable & Deinitable
    """The exact native error of constructing get, separate from running it."""
    comptime ModifyCompatible[F: UnaryContract & Movable & Deinitable]: Bool
    """Whether F is admitted, with Arg and Out exactly equal to StateType."""
    comptime Modified[F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The concrete carrier of NoneType returned by modify."""
    comptime ModifyError[F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The native construction error; execution has its own exact error."""
    @staticmethod
    def get() raises Self.GetError -> Self.Got:
        """Construct a state read when GetAvailable holds.

        Returns:
            A Family carrier whose payload is a copy of the selected state.

        Raises:
            The native construction error.
        """
        ...

    @staticmethod
    def modify[F: UnaryContract & Movable & Deinitable](var f: F) raises Self.ModifyError[F] -> Self.Modified[F]:
        """Construct an update when ModifyCompatible holds.

        Parameters:
            F: A consuming callback from StateType to StateType.

        Args:
            f: The transformation, consumed.

        Returns:
            A Family carrier with NoneType payload.

        Raises:
            The native construction error.
        """
        ...


trait Tell:
    """Append output to one explicitly selected log, in execution order.

    A compile-time capability dictionary, independent of Writer's representation.
    Tell does not require a copyable log. Its payload is NoneType.
    """
    comptime Family: Monad
    """The family in which the capability operates."""
    comptime Log: Monoid
    """The selected log monoid, retaining the exact Value type and origins."""
    comptime TellAvailable: Bool
    """Whether this selection admits constructing a log write."""
    comptime Told: Movable & Deinitable
    """The concrete carrier of NoneType returned by tell."""
    comptime TellError: Movable & Deinitable
    """The exact native construction error, separate from deferred execution."""
    @staticmethod
    def tell(var log: Self.Log.Value) raises Self.TellError -> Self.Told:
        """Construct a write when TellAvailable holds.

        Args:
            log: The output, consumed.

        Returns:
            A Family carrier with NoneType payload.

        Raises:
            The native construction error.
        """
        ...


trait Listen(Tell):
    """Observe the selected log of a computation without removing it.

    The payload becomes (value, log). Only the supplied computation is observed;
    surrounding writes remain outside that observation. Listening requires a
    copyable log, but the dictionary may still support tell for move-only logs.
    """
    comptime ListenCompatible[V: Movable & Deinitable]: Bool
    """Whether V admits observation, preserving its family and native origins."""
    comptime Listened[V: Movable & Deinitable]: Movable & Deinitable
    """The concrete Family carrier of (original payload, Log.Value)."""
    comptime ListenError[V: Movable & Deinitable]: Movable & Deinitable
    """The native construction error; execution errors remain on the carrier."""
    @staticmethod
    def listen[V: Movable & Deinitable](var value: V) raises Self.ListenError[V] -> Self.Listened[V]:
        """Observe an admitted computation's selected log.

        Parameters:
            V: A carrier satisfying ListenCompatible.

        Args:
            value: The computation, consumed.

        Returns:
            Its payload paired with a copy of its log, retaining the output log.

        Raises:
            The native construction error.
        """
        ...


trait Censor(Listen):
    """Transform the selected log of a computation, preserving its payload.

    The callback consumes the log and returns its replacement. Logs and captures
    may be move-only even when listening is unavailable. Scopes compose in
    execution order and do not affect surrounding writes or other Writer layers.
    """
    comptime CensorCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Bool
    """Whether V and F admit this scope, with Arg and Out equal to Log.Value."""
    comptime Censored[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The concrete scoped carrier, with the same payload type."""
    comptime CensorError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The native construction error, separate from execution."""
    @staticmethod
    def censor[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.CensorError[V, F] -> Self.Censored[V, F]:
        """Transform the selected log for an admitted computation and callback.

        Parameters:
            V: A carrier of Family.
            F: A consuming Log.Value-to-Log.Value transformation.

        Args:
            f: The transformation, consumed.
            value: The computation, consumed.

        Returns:
            A Family carrier preserving the original payload.

        Raises:
            The native construction error.
        """
        ...


trait Defer:
    """Build effects that run nothing until the program reaches them.

    A selected family's dictionary: generic code asks for this capability
    instead of naming a concrete family. Providers forward to their existing
    constructors. `delay` runs its function when reached and produces its
    value; `defer` builds the effect to run when reached.
    """
    comptime Family: Monad
    """The family whose carriers this capability builds."""
    comptime DelayCompatible[F: ThunkContract & Movable & Deinitable]: Bool
    """Whether F is admitted: owned, with an error the family accepts."""
    comptime Delayed[F: ThunkContract & Movable & Deinitable]: Movable & Deinitable
    """The carrier running F when reached."""
    comptime DeferCompatible[F: ThunkContract & Movable & Deinitable]: Bool
    """Whether F is admitted and returns one of the family's carriers."""
    comptime Deferred[F: ThunkContract & Movable & Deinitable]: Movable & Deinitable
    """The carrier running the effect F builds when reached."""

    @staticmethod
    def delay[F: ThunkContract & Movable & Deinitable](var function: F) -> Self.Delayed[F]:
        """Run a function when the program reaches it.

        Parameters:
            F: An admitted once-callable thunk.

        Args:
            function: The function, consumed.

        Returns:
            A carrier producing the function's value, or failing with its error.
        """
        ...

    @staticmethod
    def defer[F: ThunkContract & Movable & Deinitable](var factory: F) -> Self.Deferred[F]:
        """Build an effect when the program reaches it.

        Parameters:
            F: An admitted once-callable thunk returning a family carrier.

        Args:
            factory: The factory, consumed.

        Returns:
            A carrier running the effect the factory builds.
        """
        ...


trait Raise:
    """Fail with one ordinary domain error.

    Raising never marks the failure canceled, so the family's recovery handles
    it: raising `e` and recovering with `h` runs `h` on a failure holding only
    `e`. Families whose stored failure cannot carry cancellation can be
    `ApplicativeError` instead.
    """
    comptime Family: Monad
    """The family whose carriers this capability builds."""
    comptime Error: Movable & Deinitable
    """The domain error type."""
    comptime Raised[A: Movable & Deinitable]: Movable & Deinitable
    """The failing carrier for success type A."""

    @staticmethod
    def raise_error[A: Movable & Deinitable](var error: Self.Error) -> Self.Raised[A]:
        """Fail with one error.

        Parameters:
            A: The success type the carrier declares.

        Args:
            error: The error, consumed.

        Returns:
            A carrier failing with an uncanceled failure holding the error.
        """
        ...


trait Cancel:
    """Cancellation, masking and finalization, as Cats Effect's MonadCancel.

    Finalizers run masked with the exact exit, innermost first; a masked region
    defers observing cancellation until it ends or restores the outer state
    through its poll. Providers forward to their existing owners.
    """
    comptime Family: Monad
    """The family whose carriers this capability builds."""
    comptime Error: Movable & Deinitable
    """The domain error type."""
    comptime RegionPoll: Movable & Deinitable
    """The Poll a masked region receives to restore the outer state."""
    comptime Canceled: Movable & Deinitable
    """The unit carrier requesting cancellation of the running program."""
    comptime GuaranteeCompatible[V: Movable & Deinitable, Q: Movable & Deinitable]: Bool
    """Whether V is a family carrier and Q a unit carrier of the same error."""
    comptime Guaranteed[V: Movable & Deinitable, Q: Movable & Deinitable]: Movable & Deinitable
    """The carrier running V, then Q on every exit."""
    comptime OnCanceled[V: Movable & Deinitable, Q: Movable & Deinitable]: Movable & Deinitable
    """The carrier running V, then Q if it was canceled."""
    comptime CaseCompatible[V: Movable & Deinitable, F: Movable & Deinitable]: Bool
    """Whether F builds the finalizer from the exact exit of carrier V."""
    comptime CaseGuaranteed[V: Movable & Deinitable, F: Movable & Deinitable]: Movable & Deinitable
    """The carrier running V, then the finalizer F builds from its exit."""
    comptime UncancelableCompatible[F: UnaryContract & Movable & Deinitable]: Bool
    """Whether F takes RegionPoll and returns a family carrier."""
    comptime Uncanceled[F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The carrier running the region F builds, masked."""
    comptime RestoreCompatible[V: Movable & Deinitable]: Bool
    """Whether V is a family carrier a region's poll can restore."""
    comptime Restored[V: Movable & Deinitable]: Movable & Deinitable
    """The carrier running V with the cancellation state outside a region."""

    @staticmethod
    def canceled() -> Self.Canceled:
        """Request cancellation of the running program.

        Returns:
            A unit carrier; a mask defers observing the request.
        """
        ...

    @staticmethod
    def guarantee[V: Movable & Deinitable, Q: Movable & Deinitable](var program: V, var finalizer: Q) -> Self.Guaranteed[V, Q]:
        """Run a finalizer, masked, after the program on every exit.

        Parameters:
            V: The program's carrier type.
            Q: The finalizer's unit carrier type.

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            A carrier with the program's value; finalizer errors follow its errors.
        """
        ...

    @staticmethod
    def on_cancel[V: Movable & Deinitable, Q: Movable & Deinitable](var program: V, var finalizer: Q) -> Self.OnCanceled[V, Q]:
        """Run a finalizer, masked, only if the program is canceled.

        Parameters:
            V: The program's carrier type.
            Q: The finalizer's unit carrier type.

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            A carrier with the program's outcome and any finalizer errors.
        """
        ...

    @staticmethod
    def guarantee_case[V: Movable & Deinitable, F: Movable & Deinitable](var program: V, var finalizer: F) -> Self.CaseGuaranteed[V, F]:
        """Run a finalizer built from the program's exact exit, masked.

        Parameters:
            V: The program's carrier type.
            F: The provider's finalizer type, built from the exit.

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            A carrier with the program's value; finalizer errors follow its errors.
        """
        ...

    @staticmethod
    def restore[V: Movable & Deinitable](poll: Self.RegionPoll, var program: V) -> Self.Restored[V]:
        """Run part of a masked region with the cancellation state outside it.

        Parameters:
            V: The program's carrier type.

        Args:
            poll: The region's poll, borrowed.
            program: The program, consumed.

        Returns:
            A carrier observing cancellation as the code outside the region does.
        """
        ...

    @staticmethod
    def uncancelable[F: UnaryContract & Movable & Deinitable](var body: F) -> Self.Uncanceled[F]:
        """Run a region masked; its poll restores the outer cancellation state.

        Parameters:
            F: A once-callable taking RegionPoll and returning a family carrier.

        Args:
            body: The region's factory, consumed.

        Returns:
            The region's carrier, masked.
        """
        ...


trait Spawn(Cancel):
    """Fibers, as Cats Effect's GenSpawn, without public fiber identity.

    A started fiber runs beside the fiber that started it, its owner, which
    drains it before completing. Joining takes its outcome once.
    """
    comptime Handle[T: Movable & Deinitable]: Movable & Deinitable
    """The handle of a started fiber with success type T."""
    comptime StartCompatible[V: Movable & Deinitable]: Bool
    """Whether V is a family carrier that can be started."""
    comptime Started[V: Movable & Deinitable]: Movable & Deinitable
    """The carrier producing the handle of V started as a fiber."""
    comptime Joined[T: Movable & Deinitable]: Movable & Deinitable
    """The carrier producing a fiber's outcome with success type T."""
    comptime Stopped: Movable & Deinitable
    """The unit carrier that cancels a fiber and waits for it."""
    comptime Forever[A: Movable & Deinitable]: Movable & Deinitable
    """The carrier that waits until canceled, with success type A."""
    comptime Ceded: Movable & Deinitable
    """The unit carrier that yields to other work once."""

    @staticmethod
    def start[V: Movable & Deinitable](var program: V) -> Self.Started[V]:
        """Start the program as a fiber owned by the running fiber.

        Parameters:
            V: The program's carrier type.

        Args:
            program: The program, consumed.

        Returns:
            A carrier producing the fiber's handle.
        """
        ...

    @staticmethod
    def join[T: Movable & Deinitable](var fiber: Self.Handle[T]) -> Self.Joined[T]:
        """Wait for a fiber and its cleanup, then take its outcome.

        Parameters:
            T: The fiber's success type.

        Args:
            fiber: The handle, consumed.

        Returns:
            A carrier producing the fiber's outcome.
        """
        ...

    @staticmethod
    def cancel[T: Movable & Deinitable](fiber: Self.Handle[T]) -> Self.Stopped:
        """Cancel a fiber and wait for it to finish, without its outcome.

        Parameters:
            T: The fiber's success type.

        Args:
            fiber: The handle, borrowed.

        Returns:
            A unit carrier completing after the fiber terminates.
        """
        ...

    @staticmethod
    def never[A: Movable & Deinitable]() -> Self.Forever[A]:
        """Wait until canceled.

        Parameters:
            A: The success type the carrier declares.

        Returns:
            A carrier that never produces a value.
        """
        ...

    @staticmethod
    def cede() -> Self.Ceded:
        """Yield to other runnable work once.

        Returns:
            A unit carrier that is runnable again after one yield.
        """
        ...


trait Concurrent(Spawn):
    """Shared cells and single-assignment values, as Cats Effect's GenConcurrent.

    A provider names its handle types; copies of a handle share its state.
    Creating one is an effect, so each run of a program creates fresh state.
    Updates are atomic with respect to other fibers and never suspend; reading
    a deferred value waits until it is completed.
    """
    comptime RefHandle[T: Movable & Deinitable]: Copyable & Deinitable
    """A shared cell holding T."""
    comptime DeferredHandle[T: Copyable & Deinitable]: Copyable & Deinitable
    """A single-assignment value of T whose readers receive copies."""
    comptime RefMade[T: Movable & Deinitable]: Movable & Deinitable
    """The carrier producing a new RefHandle[T]."""
    comptime DeferredMade[T: Copyable & Deinitable]: Movable & Deinitable
    """The carrier producing a new, empty DeferredHandle[T]."""
    comptime RefRead[T: Copyable & Deinitable]: Movable & Deinitable
    """The carrier producing a copy of a cell's state."""
    comptime RefWritten: Movable & Deinitable
    """The unit carrier that replaces a cell's state."""
    comptime UpdateCompatible[T: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Bool
    """Whether F is an admitted non-raising transformation from T to T."""
    comptime RefUpdated[T: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The unit carrier that transforms a cell's state with F."""
    comptime ModifyCompatible[T: Movable & Deinitable, A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Bool
    """Whether F is an admitted non-raising transformation from T to (T, A)."""
    comptime RefModified[T: Movable & Deinitable, A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The carrier that replaces a cell's state with F and produces A."""
    comptime DeferredCompleted: Movable & Deinitable
    """The carrier producing whether a completion won."""
    comptime DeferredRead[T: Copyable & Deinitable]: Movable & Deinitable
    """The carrier waiting for a deferred value and producing a copy."""

    @staticmethod
    def make_ref[T: Movable & Deinitable](var value: T) -> Self.RefMade[T]:
        """Create a shared cell when the program reaches it.

        Parameters:
            T: The state type.

        Args:
            value: The initial state, consumed.

        Returns:
            A carrier producing the new cell.
        """
        ...

    @staticmethod
    def make_deferred[T: Copyable & Deinitable]() -> Self.DeferredMade[T]:
        """Create an empty deferred value when the program reaches it.

        Parameters:
            T: The value type.

        Returns:
            A carrier producing the new deferred value.
        """
        ...

    @staticmethod
    def get_ref[T: Copyable & Deinitable](cell: Self.RefHandle[T]) -> Self.RefRead[T]:
        """Copy a cell's state.

        Parameters:
            T: The state type.

        Args:
            cell: The cell, borrowed.

        Returns:
            A carrier producing the copy.
        """
        ...

    @staticmethod
    def set_ref[T: Movable & Deinitable](cell: Self.RefHandle[T], var value: T) -> Self.RefWritten:
        """Replace a cell's state.

        Parameters:
            T: The state type.

        Args:
            cell: The cell, borrowed.
            value: The replacement, consumed.

        Returns:
            A unit carrier.
        """
        ...

    @staticmethod
    def update_ref[T: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](cell: Self.RefHandle[T], var function: F) -> Self.RefUpdated[T, F]:
        """Transform a cell's state atomically.

        Parameters:
            T: The state type.
            F: A non-raising transformation from T to T.

        Args:
            cell: The cell, borrowed.
            function: The transformation, consumed.

        Returns:
            A unit carrier.
        """
        ...

    @staticmethod
    def modify_ref[T: Movable & Deinitable, A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](cell: Self.RefHandle[T], var function: F) -> Self.RefModified[T, A, F]:
        """Consume and replace a cell's state atomically, producing a result.

        Parameters:
            T: The state type.
            A: The result type.
            F: A non-raising transformation from T to (T, A).

        Args:
            cell: The cell, borrowed.
            function: The transformation, consumed.

        Returns:
            A carrier producing A.
        """
        ...

    @staticmethod
    def complete_deferred[T: Copyable & Deinitable](deferred: Self.DeferredHandle[T], var value: T) -> Self.DeferredCompleted:
        """Assign a deferred value once.

        Parameters:
            T: The value type.

        Args:
            deferred: The deferred value, borrowed.
            value: The value, consumed.

        Returns:
            A carrier producing whether this completion won; later ones change nothing.
        """
        ...

    @staticmethod
    def get_deferred[T: Copyable & Deinitable](deferred: Self.DeferredHandle[T]) -> Self.DeferredRead[T]:
        """Wait for a deferred value, unless canceled.

        Parameters:
            T: The value type.

        Args:
            deferred: The deferred value, borrowed.

        Returns:
            A carrier producing a copy of the value.
        """
        ...


trait Timing:
    """Read monotonic time, as Cats Effect's Clock.

    Readings come from the clock the running program inherits: the system
    monotonic clock, or a manual clock that moves only when its owner advances
    it. Instant values compare only within that clock. No wall-clock reading
    is provided.
    """
    comptime Family: Monad
    """The family whose carriers this capability builds."""
    comptime Monotonic: Movable & Deinitable
    """The carrier producing the current Instant."""
    comptime TimedCompatible[V: Movable & Deinitable]: Bool
    """Whether V is a family carrier that can be timed."""
    comptime Timed[V: Movable & Deinitable]: Movable & Deinitable
    """The carrier producing the elapsed Duration with V's value."""

    @staticmethod
    def monotonic() -> Self.Monotonic:
        """Read the inherited clock when the program reaches it.

        Returns:
            A carrier producing the current Instant.
        """
        ...

    @staticmethod
    def timed[V: Movable & Deinitable](var program: V) -> Self.Timed[V]:
        """Run a program and measure it on the inherited clock.

        Parameters:
            V: The program's carrier type.

        Args:
            program: The program, consumed.

        Returns:
            A carrier producing (elapsed Duration, value); a failure has no duration.
        """
        ...


trait Temporal(Concurrent, Timing):
    """Sleeping and timeouts, as Cats Effect's GenTemporal.

    Durations are measured on the inherited clock. A sleep suspends on a
    timer rather than polling, and a manual clock completes it only when
    advanced. A timeout cancels the program and waits for it to finish before
    the fallback runs.
    """
    comptime Slept: Movable & Deinitable
    """The unit carrier that waits for a duration."""
    comptime TemporalCompatible[V: Movable & Deinitable]: Bool
    """Whether V is a family carrier that sleeps and timeouts can run."""
    comptime TimedOut[V: Movable & Deinitable]: Movable & Deinitable
    """The carrier running V with a deadline."""
    comptime DelayedBy[V: Movable & Deinitable]: Movable & Deinitable
    """The carrier running V after a sleep."""
    comptime Waited[V: Movable & Deinitable]: Movable & Deinitable
    """The carrier running V, then sleeping, with V's value."""

    @staticmethod
    def sleep(duration: Duration) -> Self.Slept:
        """Wait for a duration measured from when the program reaches it.

        Args:
            duration: The duration.

        Returns:
            A unit carrier.
        """
        ...

    @staticmethod
    def timeout_to[V: Movable & Deinitable](var program: V, duration: Duration, var fallback: V) -> Self.TimedOut[V]:
        """Fall back after a duration, preferring the program's drained result.

        Parameters:
            V: The program's carrier type.

        Args:
            program: The program, consumed.
            duration: The deadline, measured from entry.
            fallback: Runs if the deadline passes first, consumed.

        Returns:
            A carrier with the program's or the fallback's outcome.
        """
        ...

    @staticmethod
    def timeout_after[V: Movable & Deinitable](var program: V, duration: Duration, var fallback: V) -> Self.TimedOut[V]:
        """Fall back after a duration by first terminal outcome.

        Parameters:
            V: The program's carrier type.

        Args:
            program: The program, consumed.
            duration: The deadline, measured from entry.
            fallback: Runs if the deadline passes first, consumed.

        Returns:
            A carrier with the program's or the fallback's outcome.
        """
        ...

    @staticmethod
    def timeout[V: Movable & Deinitable](var program: V, duration: Duration, var error: Self.Error) -> Self.TimedOut[V]:
        """Fail with an error after a duration, preferring the program's drained result.

        Parameters:
            V: The program's carrier type.

        Args:
            program: The program, consumed.
            duration: The deadline, measured from entry.
            error: The domain error raised on timeout, consumed.

        Returns:
            A carrier with the program's outcome or the error.
        """
        ...

    @staticmethod
    def delay_by[V: Movable & Deinitable](var program: V, duration: Duration) -> Self.DelayedBy[V]:
        """Sleep, then run the program.

        Parameters:
            V: The program's carrier type.

        Args:
            program: The program, consumed.
            duration: The sleep before it.

        Returns:
            A carrier with the program's outcome.
        """
        ...

    @staticmethod
    def and_wait[V: Movable & Deinitable](var program: V, duration: Duration) -> Self.Waited[V]:
        """Run the program, then sleep, keeping its value.

        Parameters:
            V: The program's carrier type.

        Args:
            program: The program, consumed.
            duration: The sleep after it.

        Returns:
            A carrier with the program's value after the sleep.
        """
        ...


trait Blocking:
    """Run blocking functions without blocking other work, as Cats Effect's blocking and interruptible.

    Async runs each function on a worker of the root's blocking pool while
    other fibers keep running; SyncIO runs it inline, on the calling thread,
    which the synchronous family blocks anyway. `blocking` cannot be canceled:
    cancellation and timeouts wait for it. `interruptible` lends the function
    an Interruption handle that reports a cancellation request, and
    cancellation completes when the function returns. Functions follow the
    family's callback rule: owned callables and plain functions, never
    closures or borrowed views. In Async the function, its result and its
    error move to another thread, which the caller asserts is safe.
    """
    comptime Family: Monad
    """The family whose carriers this capability builds."""
    comptime BlockingCompatible[F: ThunkContract & Movable & Deinitable]: Bool
    """Whether F is admitted: owned, with an error the family accepts."""
    comptime Blocked[F: ThunkContract & Movable & Deinitable]: Movable & Deinitable
    """The carrier running F as a blocking call."""
    comptime InterruptibleCompatible[F: BorrowCallContract & Movable & Deinitable]: Bool
    """Whether F is admitted: owned, borrowing an Interruption, with an error the family accepts."""
    comptime Interrupted[F: BorrowCallContract & Movable & Deinitable]: Movable & Deinitable
    """The carrier running F as an interruptible call."""

    @staticmethod
    def blocking[F: ThunkContract & Movable & Deinitable](var function: F) -> Self.Blocked[F]:
        """Run a blocking function when the program reaches it.

        Parameters:
            F: An admitted once-callable thunk.

        Args:
            function: The function, consumed.

        Returns:
            A carrier producing the function's value, or failing with its error.
        """
        ...

    @staticmethod
    def interruptible[F: BorrowCallContract & Movable & Deinitable](var function: F) -> Self.Interrupted[F]:
        """Run a blocking function that observes cancellation through an Interruption.

        Parameters:
            F: An admitted once-callable borrowing an Interruption.

        Args:
            function: The function, consumed.

        Returns:
            A carrier producing the function's value; canceled after it returns
            when cancellation was requested.
        """
        ...


trait _CarrierOp(Movable, Deinitable):
    """A consumed transformation of a base carrier; no stack interpretation."""
    comptime Compatible[V: Movable & Deinitable]: Bool
    comptime Applied[V: Movable & Deinitable]: Movable & Deinitable
    comptime Error[V: Movable & Deinitable]: Movable & Deinitable
    def apply[V: Movable & Deinitable](deinit self, var value: V) raises Self.Error[V] -> Self.Applied[V]: ...


trait _CapabilityLifting(_Lifting):
    comptime Base: Monad


trait _CarrierLifting(_CapabilityLifting):
    """A layer whose carriers are its base's carriers of a wrapped payload.

    Programs pass through to the base unchanged, so base operations that take
    or build programs, such as finalization and fibers, forward directly.
    """
    comptime _Wrapped[A: Movable & Deinitable]: Movable & Deinitable


trait _Hoisting(_CapabilityLifting):
    """Transport an admitted base operation through one representation."""
    comptime _HoistCompatible[V: Movable & Deinitable, H: _CarrierOp]: Bool
    comptime _Hoisted[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp]: Movable & Deinitable
    comptime _HoistError[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp]: Movable & Deinitable
    comptime _Listening[C: Listen, A: Movable & Deinitable]: _CarrierOp & Defaultable
    @staticmethod
    def _hoist[A: Movable & Deinitable, V: Movable & Deinitable, H: _CarrierOp](var op: H, var value: V
    ) raises Self._HoistError[A, V, H] -> Self._Hoisted[A, V, H]: ...


trait _LocalLifting(_Hoisting):
    """Representation-specific transport of a base scope; no interpretation."""
    comptime _ScopeCompatible[C: Local, V: Movable & Deinitable]: Bool
    comptime _Scoped[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable]: Movable & Deinitable
    comptime _ScopeError[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable]: Movable & Deinitable
    @staticmethod
    def _scope[C: Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self._ScopeError[C, V, F] -> Self._Scoped[C, V, F]:
        ...


comptime _FAMILY_MISMATCH = "run: computation belongs to a different effect family or has an incompatible native carrier"
comptime _CHOICE_FAMILY = "choice: branches belong to different effect families"
comptime _CHOICE_VALUE = "choice: branch payload types must agree"


trait _Computation(_FamilyCarrier):
    """A value that records the effect family it belongs to and its payload."""
    pass


trait ReaderAction(_Computation):
    """A computation that reads a borrowed environment when run: a value of a `ReaderT` family.

    `Family` is the `ReaderT` instance the computation belongs to and `Value`
    its payload. A result and error take the environment's origin `o`, so a
    base that keeps the environment, such as a Reader over another Reader,
    keeps its exact origin.
    """
    comptime Env: AnyType
    """The environment's type."""
    comptime Out[o: ImmOrigin]: Movable & Deinitable
    """The base carrier a run with an environment of origin `o` returns."""
    comptime Error[o: ImmOrigin]: Movable & Deinitable = Never
    """The error such a run raises; `Never` by default."""
    # Additional requirements of a library recipe at the actual run origin.
    # External actions retain their existing contract through this default.
    comptime _RunCompatible[o: ImmOrigin]: Bool = True
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) raises Self.Error[o] -> Self.Out[o]:
        """Run the computation, consuming it, with a borrowed environment.

        Parameters:
            o: The environment's origin.

        Args:
            env: The environment, borrowed for the run.

        Returns:
            The base carrier of the payload.

        Raises:
            The common error of the stages the run executes.
        """
        ...


trait StateAction(_Computation):
    """A computation that consumes a state when run and returns the base carrier of `(Value, State)`: a value of a `StateT` family."""
    comptime State: Movable & Deinitable
    """The state's type."""
    comptime Out: Movable & Deinitable
    """The base carrier a run returns."""
    comptime Error: Movable & Deinitable = Never
    """The error a run raises; `Never` by default."""
    # Requirements carried by built-in recipes; custom actions keep their contract.
    comptime _RunCompatible: Bool = True
    def run(deinit self, var state: Self.State) raises Self.Error -> Self.Out:
        """Run the computation, consuming it and the state.

        Args:
            state: The initial state, consumed.

        Returns:
            The base carrier of the payload and the final state.

        Raises:
            The common error of the stages the run executes.
        """
        ...


comptime _EndpointCompatible[M: Monad, Expected: Movable & Deinitable, Out: Movable & Deinitable] = M.CarrierCompatible[Out] and M.Element[Out] == Expected


trait _Acting(Monad):
    """A deferred family that adapts a native endpoint callback. Reader and
    State share it, so generic code can name either family's endpoint."""
    comptime Base: Monad
    comptime EndpointCompatible[T: Movable & Deinitable, F: Movable & Deinitable]: Bool
    comptime Endpoint[T: Movable & Deinitable, F: Movable & Deinitable]: Movable & Deinitable
    @staticmethod
    def endpoint[T: Movable & Deinitable, F: Movable & Deinitable](var f: F) -> Self.Endpoint[T, F]:
        ...


trait ReaderFamily(_Acting):
    """A Monad whose computations run with a borrowed Environment.

    Generic runners retain this family parameter and forward RunCompatible
    with the actual environment origin. EndpointCompatible admits action.
    """
    comptime Environment: AnyType
    comptime RunCompatible[V: Movable & Deinitable, o: ImmOrigin]: Bool


trait StateFamily(_Acting):
    """A Monad whose computations consume StateType when run.

    Generic runners forward RunCompatible; EndpointCompatible admits action.
    """
    comptime StateType: Movable & Deinitable
    comptime RunCompatible[V: Movable & Deinitable]: Bool = Self.CarrierCompatible[V]
    """Admission for running a recipe; defaults to existing carrier membership."""



trait WriterFamily(Monad):
    """A Monad carrying a Log with its payload in a Base computation.

    Unwrapped names the exact base carrier, including origins. Generic runners
    forward CarrierCompatible and return Unwrapped without private projections.
    """
    comptime Base: Monad
    comptime Log: Monoid
    comptime Unwrapped[V: Movable & Deinitable]: Movable & Deinitable
    @staticmethod
    def unwrap[V: Movable & Deinitable](var value: V) -> Self.Unwrapped[V]:
        """Remove an admitted Writer layer through its dictionary primitive.

        Parameters:
            V: A carrier admitted by CarrierCompatible.

        Args:
            value: The Writer computation, consumed.

        Returns:
            The exact base carrier, preserving its payload and origins.
        """
        ...


trait _WriterType(_Computation):
    """A Writer value: Storage is the base carrier of (log, Value)."""
    comptime Storage: Movable & Deinitable
    def into_base(deinit self) -> Self.Storage:
        ...
