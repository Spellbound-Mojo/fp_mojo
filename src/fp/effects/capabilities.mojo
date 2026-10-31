"""Explicit, compile-time selections of environment, state, log and effect capabilities."""
from std.builtin.rebind import downcast
from fp.algebra.protocols import Monad, _Lifting, _SemigroupBinary, _pure
from fp.algebra._adapt import _map_as, _flat_map_as
from fp.callables._binding import _BindSecond
from fp.callables._transforms import _Fill, _IgnoreInput
from fp.callables.protocols import BorrowCallContract, UnaryContract, OnceUnary, ThunkContract
from fp.callables.native import _NativeThunk, _NativeBorrow, _Borrowing, _RaisingBorrowing, NativeUnary, as_unary, _Unary, _RaisingUnary, _NativeOwnedArg
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error
from .protocols import Ask, Local, Stateful, Tell, Listen, Censor, Defer, Raise, Cancel, Spawn, Concurrent, Timing, Temporal, Blocking, _Hoisting, _CapabilityLifting, _CarrierLifting, _LocalLifting
from ._adapt import _lift_as
from ._timing import _LiftedClock, _LiftedSleep, _timed, _TimedOf, _TimesCompatible, _delay_by, _DelayedOf, _DelaysCompatible, _and_wait, _WaitedOf, _WaitsCompatible
from fp._internal.time import Duration
from ._transport import _CensorOp
from ._interruption import Interruption


struct LiftAsk[I: Monad & _Lifting, C: Ask](Ask):
    """Lift a selected Ask capability through one transformer.

    Selection is explicit, including when multiple layers use the same
    environment type. I.Base must equal C.Family. Nest selections to cross
    multiple layers; no runtime dictionary or carrier wrapper is introduced.

    Parameters:
        I: The destination transformer family.
        C: The capability of its immediate base.
    """
    # OptionalT/ResultT aliases expose their Identity-common traits. Refine
    # the actual transformer here without changing those native aliases.
    comptime _Layer = downcast[Self.I, _CapabilityLifting]
    comptime Family = Self.I
    comptime Environment = Self.C.Environment
    comptime AskAvailable = Self._Layer.Base == Self.C.Family and Self.C.AskAvailable
    comptime Asked = Self.I.Lifted[Self.C.Asked]
    comptime AskError = _CommonError[Self.C.AskError, Self.I.LiftError[Self.C.Asked]]
    @staticmethod
    def ask() raises Self.AskError -> Self.Asked:
        """Read the selected base environment and lift its carrier.

        Returns:
            The destination family's carrier of the environment.

        Raises:
            The common native construction error of ask and lift.
        """
        comptime assert Self.AskAvailable, "ask: unavailable capability or mismatched base family"
        comptime E = Self.AskError
        comptime assert _ErrorCompatible[E, Self.C.AskError] and _ErrorCompatible[E, Self.I.LiftError[Self.C.Asked]]
        var base: Self.C.Asked
        try:
            base = Self.C.ask()
        except error:
            _propagate_error[E](error^)
        return _lift_as[E, Self.I](base^)


struct LiftLocal[I: Monad & _Lifting, C: Local](Local):
    """Lift a selected Local (and Ask) capability through one transformer.

    Reader selects its own environment by default. Use this dictionary to
    target a Reader in its base instead. State, Writer, OptionalT and ResultT
    transport the selected scope without interpreting it.

    Parameters:
        I: The destination transformer family.
        C: The Local capability of its immediate base.
    """
    comptime _Layer = downcast[Self.I, _LocalLifting]
    comptime Family = Self.I
    comptime Environment = Self.C.Environment
    comptime _Asking = LiftAsk[Self.I, Self.C]
    comptime AskAvailable = Self._Asking.AskAvailable
    comptime Asked = Self._Asking.Asked
    comptime AskError = Self._Asking.AskError
    comptime LocalCompatible[V: Movable & Deinitable] = Self._Layer.Base == Self.C.Family and Self._Layer._ScopeCompatible[Self.C, V]
    comptime Localized[V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable] = Self._Layer._Scoped[Self.C, V, F]
    comptime LocalError[V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable] = Self._Layer._ScopeError[Self.C, V, F]
    @staticmethod
    def ask() raises Self.AskError -> Self.Asked:
        """Delegate the selected read to LiftAsk.

        Returns:
            The destination family's carrier of the environment.

        Raises:
            The common native construction error of ask and lift.
        """
        return Self._Asking.ask()

    @staticmethod
    def local[V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.LocalError[V, F] -> Self.Localized[V, F]:
        """Transport the selected base scope through the destination layer.

        Parameters:
            V: An admitted carrier of the destination family.
            F: A borrowing transformation of the selected environment.

        Args:
            f: The transformation, consumed.
            value: The computation, consumed.

        Returns:
            The scoped carrier of the destination family.

        Raises:
            The exact native scope-construction error.
        """
        comptime assert Self.LocalCompatible[V], "local: mismatched capability or carrier family"
        return Self._Layer._scope[Self.C](f^, value^)


def ask[I: Ask]() raises I.AskError -> I.Asked where I.AskAvailable:
    """Read a copy of the selected environment in the capability's family.

    Reader families select their own environment. LiftAsk and LiftLocal select
    a base capability explicitly. Generic forwarders retain AskAvailable.

    Parameters:
        I: The Ask capability; its selected environment must be Copyable.

    Returns:
        The concrete environment carrier. Deferred families remain deferred.

    Raises:
        The capability's exact native construction error.
    """
    return I.ask()


def local[V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable, //, I: Local](var value: V, var f: F
) raises I.LocalError[V, F] -> I.Localized[V, F] where I.LocalCompatible[V] and F.Payload == I.Environment and F.Result == I.Environment:
    """Run a computation under a changed selected environment.

    The transformation borrows the current environment and returns a new owned
    one. The enclosing environment is unchanged. Reader's temporary environment
    cannot escape through a deferred base; such uses remain compile errors.
    Other overloads accept a native borrowing function or closure.

    Parameters:
        V: A carrier satisfying LocalCompatible, including scope lifetime checks.
        F: A borrowing callback with Payload and Result equal to Environment.
        I: The selected Local capability, such as Reader or LiftLocal.

    Args:
        value: The computation, consumed.
        f: The environment transformation, consumed.

    Returns:
        The scoped carrier, preserving payload, origins and deferred execution.

    Raises:
        The capability's native construction error, separate from execution.
    """
    return I.local(f^, value^)


def local[V: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, //, I: Local, F: _Borrowing[P, R]](var value: V, var f: F
) raises I.LocalError[V, _NativeBorrow[P, R, Never, F, False]] -> I.Localized[V, _NativeBorrow[P, R, Never, F, False]] where I.LocalCompatible[V] and P == I.Environment and R == I.Environment:
    """Scope with an owned native borrowing function or closure."""
    return local[I](value^, _NativeBorrow[P, R, Never, F, False](f^))


def local[V: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, E: Movable & Deinitable, //, I: Local, F: _RaisingBorrowing[P, R, E]](var value: V, var f: F
) raises I.LocalError[V, _NativeBorrow[P, R, E, F, True]] -> I.Localized[V, _NativeBorrow[P, R, E, F, True]] where I.LocalCompatible[V] and P == I.Environment and R == I.Environment:
    """Scope with a raising native callback; keep its exact error type."""
    return local[I](value^, _NativeBorrow[P, R, E, F, True](f^))


@fieldwise_init
struct _Replace[S: Movable & Deinitable](OnceUnary, Copyable where conforms_to(S, Copyable)):
    var value: Self.S
    comptime Arg = Self.S
    comptime Out = Self.S
    def call_once(deinit self, var arg: Self.Arg) -> Self.Out:
        return self.value^


struct LiftStateful[I: Monad & _Lifting, C: Stateful](Stateful):
    """Lift an explicitly selected Stateful capability through one transformer.

    I.Base must equal C.Family. Nest selections to cross several layers. StateT
    selects its own state by default; this dictionary selects a base state.
    Existing lifts preserve carriers, ownership, timing and stack-order rules.

    Parameters:
        I: The destination transformer family.
        C: The Stateful capability of its immediate base.
    """
    comptime _Layer = downcast[Self.I, _CapabilityLifting]
    comptime Family = Self.I
    comptime StateType = Self.C.StateType
    comptime Got = Self.I.Lifted[Self.C.Got]
    comptime GetError = _CommonError[Self.C.GetError, Self.I.LiftError[Self.C.Got]]
    comptime GetAvailable = Self._Layer.Base == Self.C.Family and Self.C.GetAvailable and _ErrorCompatible[Self.GetError, Self.I.LiftError[Self.C.Got]]
    comptime Modified[F: UnaryContract & Movable & Deinitable] = Self.I.Lifted[Self.C.Modified[F]]
    comptime ModifyError[F: UnaryContract & Movable & Deinitable] = _CommonError[Self.C.ModifyError[F], Self.I.LiftError[Self.C.Modified[F]]]
    comptime ModifyCompatible[F: UnaryContract & Movable & Deinitable] = Self._Layer.Base == Self.C.Family and Self.C.ModifyCompatible[F] and _ErrorCompatible[Self.ModifyError[F], Self.I.LiftError[Self.C.Modified[F]]]

    @staticmethod
    def get() raises Self.GetError -> Self.Got:
        """Read the selected base state and lift its carrier.

        Returns:
            A destination carrier of the selected state.

        Raises:
            The common native construction error of get and lift.
        """
        comptime assert Self.GetAvailable, "get: unavailable capability or mismatched base family"
        comptime E = Self.GetError
        comptime assert _ErrorCompatible[E, Self.C.GetError] and _ErrorCompatible[E, Self.I.LiftError[Self.C.Got]]
        var base: Self.C.Got
        try:
            base = Self.C.get()
        except error:
            _propagate_error[E](error^)
        return _lift_as[E, Self.I](base^)

    @staticmethod
    def modify[F: UnaryContract & Movable & Deinitable](var f: F) raises Self.ModifyError[F] -> Self.Modified[F]:
        """Update the selected base state and lift its carrier.

        Parameters:
            F: A callback admitted by the selected base capability.

        Args:
            f: The state transformation, consumed.

        Returns:
            A destination carrier of NoneType.

        Raises:
            The common native construction error of modify and lift.
        """
        comptime assert Self.ModifyCompatible[F], "modify: incompatible state capability or callback"
        comptime E = Self.ModifyError[F]
        comptime assert _ErrorCompatible[E, Self.C.ModifyError[F]] and _ErrorCompatible[E, Self.I.LiftError[Self.C.Modified[F]]]
        var base: Self.C.Modified[F]
        try:
            base = Self.C.modify(f^)
        except error:
            _propagate_error[E](error^)
        return _lift_as[E, Self.I](base^)


def get[I: Stateful]() raises I.GetError -> I.Got where I.GetAvailable:
    """Read a copy of the selected state without changing it.

    State families select their own state; LiftStateful explicitly selects a
    base state. Generic forwarders retain GetAvailable in their constraints.

    Parameters:
        I: The Stateful capability; its selected state must be Copyable.

    Returns:
        A carrier of StateType in the capability's Family.

    Raises:
        The exact native construction error, separate from execution.
    """
    return I.get()


def modify[F: UnaryContract & Movable & Deinitable, //, I: Stateful](var f: F
) raises I.ModifyError[F] -> I.Modified[F] where I.ModifyCompatible[F] and F.Arg == I.StateType and F.Out == I.StateType:
    """Replace the selected state with f(state); the payload is None.

    The callback consumes the old state and returns its replacement. Both state
    and callback may be move-only. Other overloads take a native function or
    closure. Generic forwarders retain the admission and exact type constraints.

    Parameters:
        F: A consuming callback with Arg and Out exactly equal to StateType.
        I: The selected Stateful capability.

    Args:
        f: The state transformation, consumed.

    Returns:
        A carrier of NoneType in Family, preserving deferred execution.

    Raises:
        The capability's native construction error; execution errors stay native.
    """
    return I.modify(f^)


def modify[A: Movable & Deinitable, R: Movable & Deinitable, //, I: Stateful, F: _Unary[A, R]](var f: F
) raises I.ModifyError[NativeUnary[A, R, Never, F, False]] -> I.Modified[NativeUnary[A, R, Never, F, False]] where I.ModifyCompatible[NativeUnary[A, R, Never, F, False]] and A == I.StateType and R == I.StateType:
    """Update with an owned native consuming function or closure."""
    return modify[I](as_unary(f^))


def modify[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, I: Stateful, F: _RaisingUnary[A, R, E]](var f: F
) raises I.ModifyError[NativeUnary[A, R, E, F, True]] -> I.Modified[NativeUnary[A, R, E, F, True]] where I.ModifyCompatible[NativeUnary[A, R, E, F, True]] and A == I.StateType and R == I.StateType:
    """Update with a raising native callback, preserving its exact error type."""
    return modify[I](as_unary(f^))


def put[I: Stateful](var state: I.StateType
) raises I.ModifyError[_Replace[I.StateType]] -> I.Modified[_Replace[I.StateType]] where I.ModifyCompatible[_Replace[I.StateType]]:
    """Replace the selected state, destroying the previous state on execution.

    This is modify with an owned replacement, using the same execution path.

    Parameters:
        I: The selected Stateful capability.

    Args:
        state: The new state, consumed with its exact native origins.

    Returns:
        A carrier of NoneType in the capability's Family.

    Raises:
        The capability's native construction error, separate from execution.
    """
    return modify[I](_Replace[I.StateType](state^))


struct LiftTell[I: Monad & _Lifting, C: Tell](Tell):
    """Lift a selected Tell capability through one transformer.

    Selection names the immediate base capability explicitly. Nest selections
    to cross several layers; identical log types do not create ambiguity.

    Parameters:
        I: The destination transformer family.
        C: The Tell capability of its immediate base.
    """
    comptime _Layer = downcast[Self.I, _CapabilityLifting]
    comptime Family = Self.I
    comptime Log = Self.C.Log
    comptime Told = Self.I.Lifted[Self.C.Told]
    comptime TellError = _CommonError[Self.C.TellError, Self.I.LiftError[Self.C.Told]]
    comptime TellAvailable = Self._Layer.Base == Self.C.Family and Self.C.TellAvailable and _ErrorCompatible[Self.TellError, Self.I.LiftError[Self.C.Told]]
    @staticmethod
    def tell(var log: Self.Log.Value) raises Self.TellError -> Self.Told:
        """Write to the selected base log and lift the resulting carrier.

        Args:
            log: The output, consumed with its native origins.

        Returns:
            A destination carrier of NoneType.

        Raises:
            The common native construction error of tell and lift.
        """
        comptime assert Self.TellAvailable, "tell: unavailable capability or mismatched base family"
        comptime E = Self.TellError
        comptime assert _ErrorCompatible[E, Self.C.TellError] and _ErrorCompatible[E, Self.I.LiftError[Self.C.Told]]
        var base: Self.C.Told
        try: base = Self.C.tell(log^)
        except error: _propagate_error[E](error^)
        return _lift_as[E, Self.I](base^)


struct LiftListen[I: Monad & _Lifting, C: Listen](Listen):
    """Lift an explicitly selected Listen capability through one transformer.

    The selected base log stays in place. Observed logs are paired inside the
    layer's payload, retaining states, other logs, absence and stored errors.

    Parameters:
        I: The destination transformer family.
        C: The Listen capability of its immediate base.
    """
    comptime _Layer = downcast[Self.I, _Hoisting]
    comptime Family = Self.I
    comptime Log = Self.C.Log
    comptime _Telling = LiftTell[Self.I, Self.C]
    comptime TellAvailable = Self._Telling.TellAvailable
    comptime Told = Self._Telling.Told
    comptime TellError = Self._Telling.TellError
    @staticmethod
    def tell(var log: Self.Log.Value) raises Self.TellError -> Self.Told:
        """Delegate the selected write to LiftTell.

        Args:
            log: The output, consumed.

        Returns:
            A destination carrier of NoneType.

        Raises:
            The common native construction error of tell and lift.
        """
        return Self._Telling.tell(log^)
    comptime _Operation[V: Movable & Deinitable] = Self._Layer._Listening[Self.C, Self.I.Element[V]]
    comptime ListenCompatible[V: Movable & Deinitable] = Self._Layer.Base == Self.C.Family and Self._Layer._HoistCompatible[V, Self._Operation[V]]
    comptime Listened[V: Movable & Deinitable] = Self._Layer._Hoisted[Tuple[Self.I.Element[V], Self.Log.Value], V, Self._Operation[V]]
    comptime ListenError[V: Movable & Deinitable] = Self._Layer._HoistError[Tuple[Self.I.Element[V], Self.Log.Value], V, Self._Operation[V]]
    @staticmethod
    def listen[V: Movable & Deinitable](var value: V) raises Self.ListenError[V] -> Self.Listened[V]:
        """Observe the selected log, preserving the layer's representation.

        Parameters:
            V: A destination carrier admitted by ListenCompatible.

        Args:
            value: The computation, consumed.

        Returns:
            A destination carrier of (original payload, selected log).

        Raises:
            The native observation-construction error.
        """
        comptime assert Self.ListenCompatible[V], "listen: incompatible capability or carrier"
        return Self._Layer._hoist[Tuple[Self.I.Element[V], Self.Log.Value]](Self._Operation[V](), value^)


struct LiftCensor[I: Monad & _Lifting, C: Censor](Censor):
    """Lift an explicitly selected Censor capability through one transformer.

    The selected base log stays in place. Observed logs are paired inside the
    layer's payload, retaining states, other logs, absence and stored errors.

    Parameters:
        I: The destination transformer family.
        C: The Censor capability of its immediate base.
    """
    comptime _Layer = downcast[Self.I, _Hoisting]
    comptime Family = Self.I
    comptime Log = Self.C.Log
    comptime _Telling = LiftTell[Self.I, Self.C]
    comptime TellAvailable = Self._Telling.TellAvailable
    comptime Told = Self._Telling.Told
    comptime TellError = Self._Telling.TellError
    @staticmethod
    def tell(var log: Self.Log.Value) raises Self.TellError -> Self.Told:
        """Delegate the selected write to LiftTell.

        Args:
            log: The output, consumed.

        Returns:
            A destination carrier of NoneType.

        Raises:
            The common native construction error of tell and lift.
        """
        return Self._Telling.tell(log^)
    comptime _Hearing = LiftListen[Self.I, Self.C]
    comptime ListenCompatible[V: Movable & Deinitable] = Self._Hearing.ListenCompatible[V]
    comptime Listened[V: Movable & Deinitable] = Self._Hearing.Listened[V]
    comptime ListenError[V: Movable & Deinitable] = Self._Hearing.ListenError[V]
    @staticmethod
    def listen[V: Movable & Deinitable](var value: V) raises Self.ListenError[V] -> Self.Listened[V]:
        """Observe the selected log, preserving the layer's representation.

        Parameters:
            V: A destination carrier admitted by ListenCompatible.

        Args:
            value: The computation, consumed.

        Returns:
            A destination carrier of (original payload, selected log).

        Raises:
            The native observation-construction error.
        """
        return Self._Hearing.listen(value^)

    comptime CensorCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._Layer.Base == Self.C.Family and Self._Layer._HoistCompatible[V, _CensorOp[Self.C, F]]
    comptime Censored[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._Layer._Hoisted[Self.I.Element[V], V, _CensorOp[Self.C, F]]
    comptime CensorError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._Layer._HoistError[Self.I.Element[V], V, _CensorOp[Self.C, F]]
    @staticmethod
    def censor[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.CensorError[V, F] -> Self.Censored[V, F]:
        """Transform the selected base log through the shared carrier transport.

        Parameters:
            V: A destination carrier.
            F: A consuming callback admitted by CensorCompatible.

        Args:
            f: The selected log transformation, consumed.
            value: The computation, consumed.

        Returns:
            A destination carrier preserving the original payload.

        Raises:
            The native scope-construction error.
        """
        comptime assert Self.CensorCompatible[V, F], "censor: incompatible capability, carrier or callback"
        return Self._Layer._hoist[Self.I.Element[V]](_CensorOp[Self.C, F](f^), value^)


def tell[I: Tell](var log: I.Log.Value) raises I.TellError -> I.Told where I.TellAvailable:
    """Record output in the selected log, with NoneType payload.

    Writer families select their own log. LiftTell, LiftListen and LiftCensor
    explicitly select a base log. Generic forwarders retain TellAvailable.

    Parameters:
        I: The selected Tell capability.

    Args:
        log: The output, consumed with its exact native origins.

    Returns:
        A carrier of NoneType in the selected Family.

    Raises:
        The capability's exact native construction error.
    """
    return I.tell(log^)


struct TellContract[I: Censor, V: Movable & Deinitable]:
    """Append a log to an existing computation without changing its payload.

    This is the contract for two-argument tell and Pipeline.tell. The selected
    Censor capability owns admission, timing and representation. Repeated base
    maps copy the appended log; single-use maps consume it. Payloads are never
    copied by this operation. Generic wrappers forward Compatible.

    Parameters:
        I: The selected log capability, including an explicit lifted selection.
        V: The original carrier, retaining its exact native origins.
    """
    comptime Family = Self.I.Family
    """The selected capability's carrier family."""
    comptime _Append = _BindSecond[_SemigroupBinary[Self.I.Log]]
    comptime Compatible = Self.I.CensorCompatible[Self.V, Self._Append]
    """Whether this carrier admits appending, including repetition requirements."""
    comptime Out = Self.I.Censored[Self.V, Self._Append]
    """The resulting carrier with its original payload and extended log."""
    comptime Error = Self.I.CensorError[Self.V, Self._Append]
    """The native construction error; deferred errors stay on the carrier."""


def tell[V: Movable & Deinitable, //, I: Censor](var log: I.Log.Value, var value: V
) raises TellContract[I, V].Error -> TellContract[I, V].Out where TellContract[I, V].Compatible:
    """Append output after this computation's log, preserving its payload.

    The one-argument overload constructs a computation with NoneType payload.
    This overload scopes the supplied computation through Censor: it preserves
    the selected layer, stored failure behavior and deferred execution. The
    existing log is the left operand of the monoid combination. No empty log
    is constructed. A repeating base requires a copyable appended log.

    Parameters:
        V: The existing carrier.
        I: The selected Censor capability.

    Args:
        log: The appended output, consumed with its native origins.
        value: The computation, consumed without copying its payload.

    Returns:
        A carrier preserving the original payload and extending its log.

    Raises:
        The contract's exact construction error, separate from execution.
    """
    return I.censor(TellContract[I, V]._Append(_SemigroupBinary[I.Log](), log^), value^)


def listen[V: Movable & Deinitable, //, I: Listen](var value: V
) raises I.ListenError[V] -> I.Listened[V] where I.ListenCompatible[V]:
    """Pair the payload with a copy of this computation's selected log.

    The output log is retained. Only the supplied computation's log is observed;
    surrounding writes and other Writer layers are unchanged. Generic forwarders
    retain ListenCompatible, including log copyability and carrier origins.

    Parameters:
        V: A carrier admitted by ListenCompatible.
        I: The selected Listen capability.

    Args:
        value: The computation, consumed.

    Returns:
        A Family carrier whose payload is (original payload, Log.Value).

    Raises:
        The native construction error, separate from deferred execution.
    """
    return I.listen(value^)


def censor[F: UnaryContract & Movable & Deinitable, V: Movable & Deinitable, //, I: Censor](var value: V, var f: F
) raises I.CensorError[V, F] -> I.Censored[V, F] where I.CensorCompatible[V, F] and F.Arg == I.Log.Value and F.Out == I.Log.Value:
    """Replace this computation's selected log with f(log).

    The payload is preserved. The callback consumes the log; both may be
    move-only. Other overloads accept a native function or closure. Generic
    forwarders retain CensorCompatible and the exact Arg/Out log equalities.

    Parameters:
        F: A consuming Log.Value-to-Log.Value callback.
        V: A carrier of the capability's Family.
        I: The selected Censor capability.

    Args:
        value: The computation, consumed.
        f: The log transformation, consumed.

    Returns:
        A Family carrier preserving payload and native origins.

    Raises:
        The native construction error; execution errors stay native.
    """
    return I.censor(f^, value^)


def censor[A: Movable & Deinitable, R: Movable & Deinitable, V: Movable & Deinitable, //, I: Censor, F: _Unary[A, R]](var value: V, var f: F
) raises I.CensorError[V, NativeUnary[A, R, Never, F, False]] -> I.Censored[V, NativeUnary[A, R, Never, F, False]] where I.CensorCompatible[V, NativeUnary[A, R, Never, F, False]] and A == I.Log.Value and R == I.Log.Value:
    """Scope the selected log with an owned native consuming callback."""
    return censor[I](value^, as_unary(f^))


def censor[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, V: Movable & Deinitable, //, I: Censor, F: _RaisingUnary[A, R, E]](var value: V, var f: F
) raises I.CensorError[V, NativeUnary[A, R, E, F, True]] -> I.Censored[V, NativeUnary[A, R, E, F, True]] where I.CensorCompatible[V, NativeUnary[A, R, E, F, True]] and A == I.Log.Value and R == I.Log.Value:
    """Scope the selected log with a raising native callback; keep its error."""
    return censor[I](value^, as_unary(f^))


struct LiftDefer[I: Monad & _Lifting, C: Defer](Defer, not Deinitable):
    """Lift a selected Defer capability through one transformer.

    `delay` lifts the base's delayed carrier. `defer` binds the factory after
    a unit of the destination family, so the layer builds its program when
    the program reaches it. I.Base must equal C.Family. Through ReaderT over
    Async, running a deferred program is rejected like any ReaderT bind there,
    which would let the IO keep the borrowed environment; `delay` is admitted.

    Parameters:
        I: The destination transformer family.
        C: The Defer capability of its immediate base.
    """
    comptime _Layer = downcast[Self.I, _CapabilityLifting]
    comptime _Selected = Self._Layer.Base == Self.C.Family
    comptime _Build[F: ThunkContract & Movable & Deinitable] = _IgnoreInput[NoneType, F]
    comptime Family = Self.I
    comptime DelayCompatible[F: ThunkContract & Movable & Deinitable] = Self._Selected and Self.C.DelayCompatible[F] and _ErrorCompatible[Never, Self.I.LiftError[Self.C.Delayed[F]]]
    comptime Delayed[F: ThunkContract & Movable & Deinitable] = Self.I.Lifted[Self.C.Delayed[F]]
    comptime DeferCompatible[F: ThunkContract & Movable & Deinitable] = (
        Self._Selected and Self.I.BindCompatible[Self.I.Pure[NoneType], Self._Build[F]]
        and _ErrorCompatible[Never, Self.I.BindError[Self.I.Pure[NoneType], Self._Build[F]]])
    comptime Deferred[F: ThunkContract & Movable & Deinitable] = Self.I.Bound[Self.I.Pure[NoneType], Self._Build[F]]

    @staticmethod
    def delay[F: ThunkContract & Movable & Deinitable](var function: F) -> Self.Delayed[F]:
        """Lift the base's carrier that runs a function when reached.

        Parameters:
            F: A once-callable thunk the base admits.

        Args:
            function: The function, consumed.

        Returns:
            The destination family's carrier of the function's value.
        """
        comptime assert Self.DelayCompatible[F], "delay: unavailable capability or mismatched base family"
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.Delayed[F]]]
        return _lift_as[Never, Self.I](Self.C.delay(function^))

    @staticmethod
    def defer[F: ThunkContract & Movable & Deinitable](var factory: F) -> Self.Deferred[F]:
        """Build the destination family's program when the program reaches it.

        Parameters:
            F: A once-callable thunk returning a destination carrier.

        Args:
            factory: The factory, consumed.

        Returns:
            The destination family's carrier running the program F builds.
        """
        comptime assert Self.DeferCompatible[F], "defer: mismatched base family, or the layer cannot bind the factory"
        comptime assert _ErrorCompatible[Never, Self.I.BindError[Self.I.Pure[NoneType], Self._Build[F]]]
        return _flat_map_as[Never, Self.I](Self._Build[F](factory^), _pure[Self.I, NoneType](None))


struct LiftRaise[I: Monad & _Lifting, C: Raise](Raise, not Deinitable):
    """Lift a selected Raise capability through one transformer.

    The raised value is the base's domain error, not a layer's own failure
    such as ResultT's stored error. I.Base must equal C.Family.

    Parameters:
        I: The destination transformer family.
        C: The Raise capability of its immediate base.
    """
    comptime _Layer = downcast[Self.I, _CapabilityLifting]
    comptime Family = Self.I
    comptime Error = Self.C.Error
    comptime Raised[A: Movable & Deinitable] = Self.I.Lifted[Self.C.Raised[A]]

    @staticmethod
    def raise_error[A: Movable & Deinitable](var error: Self.Error) -> Self.Raised[A]:
        """Lift the base's carrier failing with one error.

        Parameters:
            A: The success type the carrier declares.

        Args:
            error: The error, consumed.

        Returns:
            The destination family's failing carrier.
        """
        comptime assert Self._Layer.Base == Self.C.Family, "raise_error: mismatched base family"
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.Raised[A]]], "raise_error: lifting into the layer must not fail"
        return _lift_as[Never, Self.I](Self.C.raise_error[A](error^))


struct LiftCancel[I: Monad & _Lifting, C: Cancel](Cancel, not Deinitable):
    """Lift a selected Cancel capability through OptionalT or ResultT.

    These layers' programs are base programs, so finalization and masking
    forward to the base: the layer's own absence or stored error is a base
    success, which runs `guarantee` finalizers and is not a cancellation.
    Finalizers are unit programs of the layer whose own result is discarded.
    `guarantee_case` takes the base's case finalizer, which observes the base
    exit. Layers with their own program representation, such as ReaderT,
    StateT and WriterT, are rejected. Like the providers, the dictionary is
    never a value, which keeps `canceled[LiftCancel[I, C]]()` from matching
    the synchronous `canceled[E]()`.

    Parameters:
        I: OptionalT or ResultT over C.Family.
        C: The Cancel capability of its immediate base.
    """
    comptime _Layer = downcast[Self.I, _CarrierLifting]
    comptime _Base = Self._Layer.Base
    # downcast does not check conformance; layers with their own representation stop here.
    comptime _Selected = conforms_to(Self.I, _CarrierLifting) and Self._Base == Self.C.Family
    comptime _Discard[Q: Movable & Deinitable] = _Fill[Self._Base.Element[Q], NoneType]
    comptime _Unit[Q: Movable & Deinitable] = Self._Base.Mapped[Q, Self._Discard[Q]]
    comptime _Finalizes[Q: Movable & Deinitable] = (
        Self.I.CarrierCompatible[Q] and Self.I.Element[Q] == NoneType
        and Self._Base.MapCompatible[Q, Self._Discard[Q]] and _ErrorCompatible[Never, Self._Base.MapError[Q, Self._Discard[Q]]])
    comptime Family = Self.I
    comptime Error = Self.C.Error
    comptime RegionPoll = Self.C.RegionPoll
    comptime Canceled = Self.I.Lifted[Self.C.Canceled]
    comptime GuaranteeCompatible[V: Movable & Deinitable, Q: Movable & Deinitable] = (
        Self._Selected and Self.I.CarrierCompatible[V] and Self._Finalizes[Q] and Self.C.GuaranteeCompatible[V, Self._Unit[Q]])
    comptime Guaranteed[V: Movable & Deinitable, Q: Movable & Deinitable] = Self.C.Guaranteed[V, Self._Unit[Q]]
    comptime OnCanceled[V: Movable & Deinitable, Q: Movable & Deinitable] = Self.C.OnCanceled[V, Self._Unit[Q]]
    comptime CaseCompatible[V: Movable & Deinitable, F: Movable & Deinitable] = Self._Selected and Self.I.CarrierCompatible[V] and Self.C.CaseCompatible[V, F]
    comptime CaseGuaranteed[V: Movable & Deinitable, F: Movable & Deinitable] = Self.C.CaseGuaranteed[V, F]
    comptime UncancelableCompatible[F: UnaryContract & Movable & Deinitable] = Self._Selected and Self.I.CarrierCompatible[F.Out] and Self.C.UncancelableCompatible[F]
    comptime Uncanceled[F: UnaryContract & Movable & Deinitable] = Self.C.Uncanceled[F]
    comptime RestoreCompatible[V: Movable & Deinitable] = Self._Selected and Self.I.CarrierCompatible[V] and Self.C.RestoreCompatible[V]
    comptime Restored[V: Movable & Deinitable] = Self.C.Restored[V]

    @staticmethod
    def _unit[Q: Movable & Deinitable](var finalizer: Q) -> Self._Unit[Q]:
        comptime assert _ErrorCompatible[Never, Self._Base.MapError[Q, Self._Discard[Q]]]
        return _map_as[Never, Self._Base](Self._Discard[Q](None), finalizer^)

    @staticmethod
    def canceled() -> Self.Canceled:
        """Lift the base's cancellation request.

        Returns:
            The destination family's unit carrier.
        """
        comptime assert Self._Selected, "canceled: mismatched base family, or a layer whose programs are not base programs"
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.Canceled]]
        return _lift_as[Never, Self.I](Self.C.canceled())

    @staticmethod
    def guarantee[V: Movable & Deinitable, Q: Movable & Deinitable](var program: V, var finalizer: Q) -> Self.Guaranteed[V, Q]:
        """Run a layer finalizer, masked, after the program on every base exit.

        Parameters:
            V: The program's carrier type.
            Q: The finalizer's unit carrier type.

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            The base's guaranteed carrier, a carrier of the destination family.
        """
        comptime assert Self.GuaranteeCompatible[V, Q], "guarantee: unsupported layer, mismatched base family, program or unit finalizer"
        return Self.C.guarantee(program^, Self._unit(finalizer^))

    @staticmethod
    def on_cancel[V: Movable & Deinitable, Q: Movable & Deinitable](var program: V, var finalizer: Q) -> Self.OnCanceled[V, Q]:
        """Run a layer finalizer, masked, only if the program is canceled.

        Parameters:
            V: The program's carrier type.
            Q: The finalizer's unit carrier type.

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            The base's carrier, a carrier of the destination family.
        """
        comptime assert Self.GuaranteeCompatible[V, Q], "on_cancel: unsupported layer, mismatched base family, program or unit finalizer"
        return Self.C.on_cancel(program^, Self._unit(finalizer^))

    @staticmethod
    def guarantee_case[V: Movable & Deinitable, F: Movable & Deinitable](var program: V, var finalizer: F) -> Self.CaseGuaranteed[V, F]:
        """Run the base's case finalizer, masked, with the program's base exit.

        Parameters:
            V: The program's carrier type.
            F: The base provider's case finalizer type.

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            The base's carrier, a carrier of the destination family.
        """
        comptime assert Self.CaseCompatible[V, F], "guarantee_case: unsupported layer, mismatched base family, program or case finalizer"
        return Self.C.guarantee_case(program^, finalizer^)

    @staticmethod
    def restore[V: Movable & Deinitable](poll: Self.RegionPoll, var program: V) -> Self.Restored[V]:
        """Run part of a masked region with the cancellation state outside it.

        Parameters:
            V: The program's carrier type.

        Args:
            poll: The region's poll, borrowed.
            program: The program, consumed.

        Returns:
            The base's carrier, a carrier of the destination family.
        """
        comptime assert Self.RestoreCompatible[V], "restore: unsupported layer, mismatched base family or program"
        return Self.C.restore(poll, program^)

    @staticmethod
    def uncancelable[F: UnaryContract & Movable & Deinitable](var body: F) -> Self.Uncanceled[F]:
        """Run a region of layer programs masked; its poll restores the outer state.

        Parameters:
            F: A once-callable taking RegionPoll and returning a layer carrier.

        Args:
            body: The region's factory, consumed.

        Returns:
            The base's masked carrier, a carrier of the destination family.
        """
        comptime assert Self.UncancelableCompatible[F], "uncancelable: unsupported layer, mismatched base family or region"
        return Self.C.uncancelable(body^)


struct LiftSpawn[I: Monad & _Lifting, C: Spawn](Spawn, not Deinitable):
    """Lift a selected Spawn capability through OptionalT or ResultT.

    A layer program starts as a base fiber whose success is the layer's
    payload: a fiber of OptionalT[Async[E]] with success type T is a
    Fiber[Optional[T], E], and joining it produces the layer's absence or
    stored error inside a successful outcome. Operations that produce values
    lift the base's carriers; Cancel members delegate to LiftCancel.

    Parameters:
        I: OptionalT or ResultT over C.Family.
        C: The Spawn capability of its immediate base.
    """
    comptime _Canceling = LiftCancel[Self.I, Self.C]
    comptime _Layer = downcast[Self.I, _CarrierLifting]
    comptime _Selected = Self._Canceling._Selected
    comptime Family = Self.I
    comptime Error = Self.C.Error
    comptime RegionPoll = Self._Canceling.RegionPoll
    comptime Canceled = Self._Canceling.Canceled
    comptime GuaranteeCompatible[V: Movable & Deinitable, Q: Movable & Deinitable] = Self._Canceling.GuaranteeCompatible[V, Q]
    comptime Guaranteed[V: Movable & Deinitable, Q: Movable & Deinitable] = Self._Canceling.Guaranteed[V, Q]
    comptime OnCanceled[V: Movable & Deinitable, Q: Movable & Deinitable] = Self._Canceling.OnCanceled[V, Q]
    comptime CaseCompatible[V: Movable & Deinitable, F: Movable & Deinitable] = Self._Canceling.CaseCompatible[V, F]
    comptime CaseGuaranteed[V: Movable & Deinitable, F: Movable & Deinitable] = Self._Canceling.CaseGuaranteed[V, F]
    comptime UncancelableCompatible[F: UnaryContract & Movable & Deinitable] = Self._Canceling.UncancelableCompatible[F]
    comptime Uncanceled[F: UnaryContract & Movable & Deinitable] = Self._Canceling.Uncanceled[F]
    comptime RestoreCompatible[V: Movable & Deinitable] = Self._Canceling.RestoreCompatible[V]
    comptime Restored[V: Movable & Deinitable] = Self._Canceling.Restored[V]
    comptime Handle[T: Movable & Deinitable] = Self.C.Handle[Self._Layer._Wrapped[T]]
    comptime StartCompatible[V: Movable & Deinitable] = (
        Self._Selected and Self.I.CarrierCompatible[V] and Self.C.StartCompatible[V]
        and _ErrorCompatible[Never, Self.I.LiftError[Self.C.Started[V]]])
    comptime Started[V: Movable & Deinitable] = Self.I.Lifted[Self.C.Started[V]]
    comptime Joined[T: Movable & Deinitable] = Self.I.Lifted[Self.C.Joined[Self._Layer._Wrapped[T]]]
    comptime Stopped = Self.I.Lifted[Self.C.Stopped]
    comptime Forever[A: Movable & Deinitable] = Self.I.Lifted[Self.C.Forever[A]]
    comptime Ceded = Self.I.Lifted[Self.C.Ceded]

    @staticmethod
    def canceled() -> Self.Canceled:
        """Delegate to LiftCancel.

        Returns:
            The destination family's unit carrier.
        """
        return Self._Canceling.canceled()

    @staticmethod
    def guarantee[V: Movable & Deinitable, Q: Movable & Deinitable](var program: V, var finalizer: Q) -> Self.Guaranteed[V, Q]:
        """Delegate to LiftCancel.

        Parameters:
            V: The program's carrier type.
            Q: The finalizer's unit carrier type.

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            The base's guaranteed carrier.
        """
        return Self._Canceling.guarantee(program^, finalizer^)

    @staticmethod
    def on_cancel[V: Movable & Deinitable, Q: Movable & Deinitable](var program: V, var finalizer: Q) -> Self.OnCanceled[V, Q]:
        """Delegate to LiftCancel.

        Parameters:
            V: The program's carrier type.
            Q: The finalizer's unit carrier type.

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            The base's carrier.
        """
        return Self._Canceling.on_cancel(program^, finalizer^)

    @staticmethod
    def guarantee_case[V: Movable & Deinitable, F: Movable & Deinitable](var program: V, var finalizer: F) -> Self.CaseGuaranteed[V, F]:
        """Delegate to LiftCancel.

        Parameters:
            V: The program's carrier type.
            F: The base provider's case finalizer type.

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            The base's carrier.
        """
        return Self._Canceling.guarantee_case(program^, finalizer^)

    @staticmethod
    def restore[V: Movable & Deinitable](poll: Self.RegionPoll, var program: V) -> Self.Restored[V]:
        """Delegate to LiftCancel.

        Parameters:
            V: The program's carrier type.

        Args:
            poll: The region's poll, borrowed.
            program: The program, consumed.

        Returns:
            The base's carrier.
        """
        return Self._Canceling.restore(poll, program^)

    @staticmethod
    def uncancelable[F: UnaryContract & Movable & Deinitable](var body: F) -> Self.Uncanceled[F]:
        """Delegate to LiftCancel.

        Parameters:
            F: A once-callable taking RegionPoll and returning a layer carrier.

        Args:
            body: The region's factory, consumed.

        Returns:
            The base's masked carrier.
        """
        return Self._Canceling.uncancelable(body^)

    @staticmethod
    def start[V: Movable & Deinitable](var program: V) -> Self.Started[V]:
        """Start a layer program as a base fiber and lift its handle.

        Parameters:
            V: The program's carrier type.

        Args:
            program: The program, consumed.

        Returns:
            The destination family's carrier of the fiber's handle.
        """
        comptime assert Self.StartCompatible[V], "start: unsupported layer, mismatched base family or program"
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.Started[V]]]
        return _lift_as[Never, Self.I](Self.C.start(program^))

    @staticmethod
    def join[T: Movable & Deinitable](var fiber: Self.Handle[T]) -> Self.Joined[T]:
        """Join a layer fiber and lift its base outcome.

        Parameters:
            T: The layer program's success type.

        Args:
            fiber: The handle, consumed.

        Returns:
            The destination family's carrier of the outcome.
        """
        comptime assert Self._Selected, "join: mismatched base family, or a layer whose programs are not base programs"
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.Joined[Self._Layer._Wrapped[T]]]]
        return _lift_as[Never, Self.I](Self.C.join[Self._Layer._Wrapped[T]](fiber^))

    @staticmethod
    def cancel[T: Movable & Deinitable](fiber: Self.Handle[T]) -> Self.Stopped:
        """Cancel a layer fiber and wait for it, lifting the base's carrier.

        Parameters:
            T: The layer program's success type.

        Args:
            fiber: The handle, borrowed.

        Returns:
            The destination family's unit carrier.
        """
        comptime assert Self._Selected, "cancel: mismatched base family, or a layer whose programs are not base programs"
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.Stopped]]
        return _lift_as[Never, Self.I](Self.C.cancel[Self._Layer._Wrapped[T]](fiber))

    @staticmethod
    def never[A: Movable & Deinitable]() -> Self.Forever[A]:
        """Lift the base's carrier that waits until canceled.

        Parameters:
            A: The success type the carrier declares.

        Returns:
            The destination family's carrier.
        """
        comptime assert Self._Selected, "never: mismatched base family, or a layer whose programs are not base programs"
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.Forever[A]]]
        return _lift_as[Never, Self.I](Self.C.never[A]())

    @staticmethod
    def cede() -> Self.Ceded:
        """Lift the base's carrier that yields once.

        Returns:
            The destination family's unit carrier.
        """
        comptime assert Self._Selected, "cede: mismatched base family, or a layer whose programs are not base programs"
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.Ceded]]
        return _lift_as[Never, Self.I](Self.C.cede())


struct LiftConcurrent[I: Monad & _Lifting, C: Concurrent](Concurrent, not Deinitable):
    """Lift a selected Concurrent capability through OptionalT or ResultT.

    The handles are the base's: a cell made through the layer is the base's
    cell, shared with base programs. Creation, reads, writes, and updates lift
    the base's carriers, so each produces the layer's success. Spawn and Cancel
    members delegate to LiftSpawn, which admits only layers whose programs are
    base programs.

    Parameters:
        I: OptionalT or ResultT over C.Family.
        C: The Concurrent capability of its immediate base.
    """
    comptime _Spawning = LiftSpawn[Self.I, Self.C]
    comptime _Selected = Self._Spawning._Selected
    comptime _Lifts[V: Movable & Deinitable] = _ErrorCompatible[Never, Self.I.LiftError[V]]
    comptime Family = Self.I
    comptime Error = Self.C.Error
    comptime RegionPoll = Self._Spawning.RegionPoll
    comptime Canceled = Self._Spawning.Canceled
    comptime Stopped = Self._Spawning.Stopped
    comptime Ceded = Self._Spawning.Ceded
    comptime GuaranteeCompatible[V: Movable & Deinitable, Q: Movable & Deinitable] = Self._Spawning.GuaranteeCompatible[V, Q]
    comptime Guaranteed[V: Movable & Deinitable, Q: Movable & Deinitable] = Self._Spawning.Guaranteed[V, Q]
    comptime OnCanceled[V: Movable & Deinitable, Q: Movable & Deinitable] = Self._Spawning.OnCanceled[V, Q]
    comptime CaseCompatible[V: Movable & Deinitable, F: Movable & Deinitable] = Self._Spawning.CaseCompatible[V, F]
    comptime CaseGuaranteed[V: Movable & Deinitable, F: Movable & Deinitable] = Self._Spawning.CaseGuaranteed[V, F]
    comptime UncancelableCompatible[F: UnaryContract & Movable & Deinitable] = Self._Spawning.UncancelableCompatible[F]
    comptime Uncanceled[F: UnaryContract & Movable & Deinitable] = Self._Spawning.Uncanceled[F]
    comptime RestoreCompatible[V: Movable & Deinitable] = Self._Spawning.RestoreCompatible[V]
    comptime Restored[V: Movable & Deinitable] = Self._Spawning.Restored[V]
    comptime Handle[T: Movable & Deinitable] = Self._Spawning.Handle[T]
    comptime StartCompatible[V: Movable & Deinitable] = Self._Spawning.StartCompatible[V]
    comptime Started[V: Movable & Deinitable] = Self._Spawning.Started[V]
    comptime Joined[T: Movable & Deinitable] = Self._Spawning.Joined[T]
    comptime Forever[A: Movable & Deinitable] = Self._Spawning.Forever[A]
    comptime RefHandle[T: Movable & Deinitable] = Self.C.RefHandle[T]
    comptime DeferredHandle[T: Copyable & Deinitable] = Self.C.DeferredHandle[T]
    comptime RefMade[T: Movable & Deinitable] = Self.I.Lifted[Self.C.RefMade[T]]
    comptime DeferredMade[T: Copyable & Deinitable] = Self.I.Lifted[Self.C.DeferredMade[T]]
    comptime RefRead[T: Copyable & Deinitable] = Self.I.Lifted[Self.C.RefRead[T]]
    comptime RefWritten = Self.I.Lifted[Self.C.RefWritten]
    comptime UpdateCompatible[T: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._Selected and Self.C.UpdateCompatible[T, F] and Self._Lifts[Self.C.RefUpdated[T, F]]
    comptime RefUpdated[T: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.I.Lifted[Self.C.RefUpdated[T, F]]
    comptime ModifyCompatible[T: Movable & Deinitable, A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._Selected and Self.C.ModifyCompatible[T, A, F] and Self._Lifts[Self.C.RefModified[T, A, F]]
    comptime RefModified[T: Movable & Deinitable, A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.I.Lifted[Self.C.RefModified[T, A, F]]
    comptime DeferredCompleted = Self.I.Lifted[Self.C.DeferredCompleted]
    comptime DeferredRead[T: Copyable & Deinitable] = Self.I.Lifted[Self.C.DeferredRead[T]]

    @staticmethod
    def canceled() -> Self.Canceled:
        """Delegate to LiftSpawn.

        Returns:
            The destination family's unit carrier.
        """
        return Self._Spawning.canceled()

    @staticmethod
    def guarantee[V: Movable & Deinitable, Q: Movable & Deinitable](var program: V, var finalizer: Q) -> Self.Guaranteed[V, Q]:
        """Delegate to LiftSpawn.

        Parameters:
            V: The program's carrier type.
            Q: The finalizer's unit carrier type.

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            The base's guaranteed carrier.
        """
        return Self._Spawning.guarantee(program^, finalizer^)

    @staticmethod
    def on_cancel[V: Movable & Deinitable, Q: Movable & Deinitable](var program: V, var finalizer: Q) -> Self.OnCanceled[V, Q]:
        """Delegate to LiftSpawn.

        Parameters:
            V: The program's carrier type.
            Q: The finalizer's unit carrier type.

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            The base's carrier.
        """
        return Self._Spawning.on_cancel(program^, finalizer^)

    @staticmethod
    def guarantee_case[V: Movable & Deinitable, F: Movable & Deinitable](var program: V, var finalizer: F) -> Self.CaseGuaranteed[V, F]:
        """Delegate to LiftSpawn.

        Parameters:
            V: The program's carrier type.
            F: The base provider's case finalizer type.

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            The base's carrier.
        """
        return Self._Spawning.guarantee_case(program^, finalizer^)

    @staticmethod
    def restore[V: Movable & Deinitable](poll: Self.RegionPoll, var program: V) -> Self.Restored[V]:
        """Delegate to LiftSpawn.

        Parameters:
            V: The program's carrier type.

        Args:
            poll: The region's poll, borrowed.
            program: The program, consumed.

        Returns:
            The base's carrier.
        """
        return Self._Spawning.restore(poll, program^)

    @staticmethod
    def uncancelable[F: UnaryContract & Movable & Deinitable](var body: F) -> Self.Uncanceled[F]:
        """Delegate to LiftSpawn.

        Parameters:
            F: A once-callable taking RegionPoll and returning a layer carrier.

        Args:
            body: The region's factory, consumed.

        Returns:
            The base's masked carrier.
        """
        return Self._Spawning.uncancelable(body^)

    @staticmethod
    def start[V: Movable & Deinitable](var program: V) -> Self.Started[V]:
        """Delegate to LiftSpawn.

        Parameters:
            V: The program's carrier type.

        Args:
            program: The program, consumed.

        Returns:
            The destination family's carrier of the fiber's handle.
        """
        return Self._Spawning.start(program^)

    @staticmethod
    def join[T: Movable & Deinitable](var fiber: Self.Handle[T]) -> Self.Joined[T]:
        """Delegate to LiftSpawn.

        Parameters:
            T: The layer program's success type.

        Args:
            fiber: The handle, consumed.

        Returns:
            The destination family's carrier of the outcome.
        """
        return Self._Spawning.join[T](fiber^)

    @staticmethod
    def cancel[T: Movable & Deinitable](fiber: Self.Handle[T]) -> Self.Stopped:
        """Delegate to LiftSpawn.

        Parameters:
            T: The layer program's success type.

        Args:
            fiber: The handle, borrowed.

        Returns:
            The destination family's unit carrier.
        """
        return Self._Spawning.cancel[T](fiber)

    @staticmethod
    def never[A: Movable & Deinitable]() -> Self.Forever[A]:
        """Delegate to LiftSpawn.

        Parameters:
            A: The success type the carrier declares.

        Returns:
            The destination family's carrier.
        """
        return Self._Spawning.never[A]()

    @staticmethod
    def cede() -> Self.Ceded:
        """Delegate to LiftSpawn.

        Returns:
            The destination family's unit carrier.
        """
        return Self._Spawning.cede()

    @staticmethod
    def make_ref[T: Movable & Deinitable](var value: T) -> Self.RefMade[T]:
        """Lift the base's carrier that creates a cell.

        Parameters:
            T: The state type.

        Args:
            value: The initial state, consumed.

        Returns:
            The destination family's carrier of the new cell.
        """
        comptime assert Self._Selected, "make_ref: mismatched base family, or a layer whose programs are not base programs"
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.RefMade[T]]]
        return _lift_as[Never, Self.I](Self.C.make_ref(value^))

    @staticmethod
    def make_deferred[T: Copyable & Deinitable]() -> Self.DeferredMade[T]:
        """Lift the base's carrier that creates a deferred value.

        Parameters:
            T: The value type.

        Returns:
            The destination family's carrier of the new deferred value.
        """
        comptime assert Self._Selected, "make_deferred: mismatched base family, or a layer whose programs are not base programs"
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.DeferredMade[T]]]
        return _lift_as[Never, Self.I](Self.C.make_deferred[T]())

    @staticmethod
    def get_ref[T: Copyable & Deinitable](cell: Self.RefHandle[T]) -> Self.RefRead[T]:
        """Lift the base's carrier that copies a cell's state.

        Parameters:
            T: The state type.

        Args:
            cell: The cell, borrowed.

        Returns:
            The destination family's carrier of the copy.
        """
        comptime assert Self._Selected, "get_ref: mismatched base family, or a layer whose programs are not base programs"
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.RefRead[T]]]
        return _lift_as[Never, Self.I](Self.C.get_ref[T](cell))

    @staticmethod
    def set_ref[T: Movable & Deinitable](cell: Self.RefHandle[T], var value: T) -> Self.RefWritten:
        """Lift the base's carrier that replaces a cell's state.

        Parameters:
            T: The state type.

        Args:
            cell: The cell, borrowed.
            value: The replacement, consumed.

        Returns:
            The destination family's unit carrier.
        """
        comptime assert Self._Selected, "set_ref: mismatched base family, or a layer whose programs are not base programs"
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.RefWritten]]
        return _lift_as[Never, Self.I](Self.C.set_ref[T](cell, value^))

    @staticmethod
    def update_ref[T: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](cell: Self.RefHandle[T], var function: F) -> Self.RefUpdated[T, F]:
        """Lift the base's carrier that transforms a cell's state.

        Parameters:
            T: The state type.
            F: A non-raising transformation from T to T.

        Args:
            cell: The cell, borrowed.
            function: The transformation, consumed.

        Returns:
            The destination family's unit carrier.
        """
        comptime assert Self.UpdateCompatible[T, F], "update_ref: unsupported layer, mismatched base family or transformation"
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.RefUpdated[T, F]]]
        return _lift_as[Never, Self.I](Self.C.update_ref[T, F](cell, function^))

    @staticmethod
    def modify_ref[T: Movable & Deinitable, A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](cell: Self.RefHandle[T], var function: F) -> Self.RefModified[T, A, F]:
        """Lift the base's carrier that replaces a cell's state and produces a result.

        Parameters:
            T: The state type.
            A: The result type.
            F: A non-raising transformation from T to (T, A).

        Args:
            cell: The cell, borrowed.
            function: The transformation, consumed.

        Returns:
            The destination family's carrier of A.
        """
        comptime assert Self.ModifyCompatible[T, A, F], "modify_ref: unsupported layer, mismatched base family or transformation"
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.RefModified[T, A, F]]]
        return _lift_as[Never, Self.I](Self.C.modify_ref[T, A, F](cell, function^))

    @staticmethod
    def complete_deferred[T: Copyable & Deinitable](deferred: Self.DeferredHandle[T], var value: T) -> Self.DeferredCompleted:
        """Lift the base's carrier that completes a deferred value.

        Parameters:
            T: The value type.

        Args:
            deferred: The deferred value, borrowed.
            value: The value, consumed.

        Returns:
            The destination family's carrier of whether this completion won.
        """
        comptime assert Self._Selected, "complete_deferred: mismatched base family, or a layer whose programs are not base programs"
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.DeferredCompleted]]
        return _lift_as[Never, Self.I](Self.C.complete_deferred[T](deferred, value^))

    @staticmethod
    def get_deferred[T: Copyable & Deinitable](deferred: Self.DeferredHandle[T]) -> Self.DeferredRead[T]:
        """Lift the base's carrier that waits for a deferred value.

        Parameters:
            T: The value type.

        Args:
            deferred: The deferred value, borrowed.

        Returns:
            The destination family's carrier of the value.
        """
        comptime assert Self._Selected, "get_deferred: mismatched base family, or a layer whose programs are not base programs"
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.DeferredRead[T]]]
        return _lift_as[Never, Self.I](Self.C.get_deferred[T](deferred))


struct LiftTiming[I: Monad & _Lifting, C: Timing](Timing, not Deinitable):
    """Lift a selected Timing capability through one transformer.

    `monotonic` lifts the base's reading. `timed` binds through the
    destination family, as Cats Effect derives it, so a layer's absence or
    stored error skips the second reading. I.Base must equal C.Family. Through
    ReaderT over Async, running a timed program is rejected like any ReaderT
    bind there.

    Parameters:
        I: The destination transformer family.
        C: The Timing capability of its immediate base.
    """
    comptime _Layer = downcast[Self.I, _CapabilityLifting]
    comptime _Source = _LiftedClock[Self.I, Self.C]
    comptime _Selected = Self._Layer.Base == Self.C.Family and _ErrorCompatible[Never, Self.I.LiftError[Self.C.Monotonic]]
    comptime Family = Self.I
    comptime Monotonic = Self._Source.Reading
    comptime TimedCompatible[V: Movable & Deinitable] = Self._Selected and _TimesCompatible[Self._Source, V]
    comptime Timed[V: Movable & Deinitable] = _TimedOf[Self._Source, V]

    @staticmethod
    def monotonic() -> Self.Monotonic:
        """Lift the base's clock reading.

        Returns:
            The destination family's carrier of the current Instant.
        """
        comptime assert Self._Selected, "monotonic: mismatched base family"
        return Self._Source.read()

    @staticmethod
    def timed[V: Movable & Deinitable](var program: V) -> Self.Timed[V]:
        """Measure a layer program with the lifted clock reading.

        Parameters:
            V: The program's carrier type.

        Args:
            program: The program, consumed.

        Returns:
            The destination family's carrier of the duration and value.
        """
        comptime assert Self.TimedCompatible[V], "timed: mismatched base family, or the layer cannot bind the program"
        return _timed[Self._Source, V](program^)


struct LiftTemporal[I: Monad & _Lifting, C: Temporal](Temporal, not Deinitable):
    """Lift a selected Temporal capability through OptionalT or ResultT.

    `sleep` lifts the base's. Timeouts forward the layer's programs, which are
    base programs, so a layer's absence or stored error is a base success that
    beats the deadline; `timeout` raises the base's domain error. `delay_by`
    and `and_wait` bind through the destination family, as Cats Effect derives
    them, so a layer's absence skips the sleep after it. Concurrent members
    delegate to LiftConcurrent; Timing members read the same lifted clock as
    LiftTiming.

    Parameters:
        I: OptionalT or ResultT over C.Family.
        C: The Temporal capability of its immediate base.
    """
    comptime _Concurrent = LiftConcurrent[Self.I, Self.C]
    comptime _Selected = Self._Concurrent._Selected
    comptime Family = Self.I
    comptime Error = Self.C.Error
    comptime RegionPoll = Self._Concurrent.RegionPoll
    comptime Canceled = Self._Concurrent.Canceled
    comptime Stopped = Self._Concurrent.Stopped
    comptime Ceded = Self._Concurrent.Ceded
    comptime RefWritten = Self._Concurrent.RefWritten
    comptime DeferredCompleted = Self._Concurrent.DeferredCompleted
    comptime GuaranteeCompatible[V: Movable & Deinitable, Q: Movable & Deinitable] = Self._Concurrent.GuaranteeCompatible[V, Q]
    comptime Guaranteed[V: Movable & Deinitable, Q: Movable & Deinitable] = Self._Concurrent.Guaranteed[V, Q]
    comptime OnCanceled[V: Movable & Deinitable, Q: Movable & Deinitable] = Self._Concurrent.OnCanceled[V, Q]
    comptime CaseCompatible[V: Movable & Deinitable, F: Movable & Deinitable] = Self._Concurrent.CaseCompatible[V, F]
    comptime CaseGuaranteed[V: Movable & Deinitable, F: Movable & Deinitable] = Self._Concurrent.CaseGuaranteed[V, F]
    comptime UncancelableCompatible[F: UnaryContract & Movable & Deinitable] = Self._Concurrent.UncancelableCompatible[F]
    comptime Uncanceled[F: UnaryContract & Movable & Deinitable] = Self._Concurrent.Uncanceled[F]
    comptime RestoreCompatible[V: Movable & Deinitable] = Self._Concurrent.RestoreCompatible[V]
    comptime Restored[V: Movable & Deinitable] = Self._Concurrent.Restored[V]
    comptime Handle[T: Movable & Deinitable] = Self._Concurrent.Handle[T]
    comptime StartCompatible[V: Movable & Deinitable] = Self._Concurrent.StartCompatible[V]
    comptime Started[V: Movable & Deinitable] = Self._Concurrent.Started[V]
    comptime Joined[T: Movable & Deinitable] = Self._Concurrent.Joined[T]
    comptime Forever[A: Movable & Deinitable] = Self._Concurrent.Forever[A]
    comptime RefHandle[T: Movable & Deinitable] = Self._Concurrent.RefHandle[T]
    comptime DeferredHandle[T: Copyable & Deinitable] = Self._Concurrent.DeferredHandle[T]
    comptime RefMade[T: Movable & Deinitable] = Self._Concurrent.RefMade[T]
    comptime DeferredMade[T: Copyable & Deinitable] = Self._Concurrent.DeferredMade[T]
    comptime RefRead[T: Copyable & Deinitable] = Self._Concurrent.RefRead[T]
    comptime UpdateCompatible[T: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._Concurrent.UpdateCompatible[T, F]
    comptime RefUpdated[T: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._Concurrent.RefUpdated[T, F]
    comptime ModifyCompatible[T: Movable & Deinitable, A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._Concurrent.ModifyCompatible[T, A, F]
    comptime RefModified[T: Movable & Deinitable, A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self._Concurrent.RefModified[T, A, F]
    comptime DeferredRead[T: Copyable & Deinitable] = Self._Concurrent.DeferredRead[T]
    comptime _Source = _LiftedSleep[Self.I, Self.C]
    comptime Monotonic = Self._Source.Reading
    comptime TimedCompatible[V: Movable & Deinitable] = Self._Selected and _TimesCompatible[Self._Source, V]
    comptime Timed[V: Movable & Deinitable] = _TimedOf[Self._Source, V]
    comptime Slept = Self._Source.Slept
    comptime TemporalCompatible[V: Movable & Deinitable] = (
        Self._Selected and Self.I.CarrierCompatible[V] and Self.C.TemporalCompatible[V]
        and _ErrorCompatible[Never, Self.I.LiftError[Self.C.Slept]]
        and _DelaysCompatible[Self._Source, V] and _WaitsCompatible[Self._Source, V])
    comptime TimedOut[V: Movable & Deinitable] = Self.C.TimedOut[V]
    comptime DelayedBy[V: Movable & Deinitable] = _DelayedOf[Self._Source, V]
    comptime Waited[V: Movable & Deinitable] = _WaitedOf[Self._Source, V]

    @staticmethod
    def canceled() -> Self.Canceled:
        """Delegate to LiftConcurrent.

        Returns:
            The destination family's unit carrier.
        """
        return Self._Concurrent.canceled()

    @staticmethod
    def guarantee[V: Movable & Deinitable, Q: Movable & Deinitable](var program: V, var finalizer: Q) -> Self.Guaranteed[V, Q]:
        """Delegate to LiftConcurrent.

        Parameters:
            V: The program's carrier type.
            Q: The finalizer's unit carrier type.

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            The base's guaranteed carrier.
        """
        return Self._Concurrent.guarantee(program^, finalizer^)

    @staticmethod
    def on_cancel[V: Movable & Deinitable, Q: Movable & Deinitable](var program: V, var finalizer: Q) -> Self.OnCanceled[V, Q]:
        """Delegate to LiftConcurrent.

        Parameters:
            V: The program's carrier type.
            Q: The finalizer's unit carrier type.

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            The base's carrier.
        """
        return Self._Concurrent.on_cancel(program^, finalizer^)

    @staticmethod
    def guarantee_case[V: Movable & Deinitable, F: Movable & Deinitable](var program: V, var finalizer: F) -> Self.CaseGuaranteed[V, F]:
        """Delegate to LiftConcurrent.

        Parameters:
            V: The program's carrier type.
            F: The base provider's case finalizer type.

        Args:
            program: The program, consumed.
            finalizer: The finalizer, consumed.

        Returns:
            The base's carrier.
        """
        return Self._Concurrent.guarantee_case(program^, finalizer^)

    @staticmethod
    def restore[V: Movable & Deinitable](poll: Self.RegionPoll, var program: V) -> Self.Restored[V]:
        """Delegate to LiftConcurrent.

        Parameters:
            V: The program's carrier type.

        Args:
            poll: The region's poll, borrowed.
            program: The program, consumed.

        Returns:
            The base's carrier.
        """
        return Self._Concurrent.restore(poll, program^)

    @staticmethod
    def uncancelable[F: UnaryContract & Movable & Deinitable](var body: F) -> Self.Uncanceled[F]:
        """Delegate to LiftConcurrent.

        Parameters:
            F: A once-callable taking RegionPoll and returning a layer carrier.

        Args:
            body: The region's factory, consumed.

        Returns:
            The base's masked carrier.
        """
        return Self._Concurrent.uncancelable(body^)

    @staticmethod
    def start[V: Movable & Deinitable](var program: V) -> Self.Started[V]:
        """Delegate to LiftConcurrent.

        Parameters:
            V: The program's carrier type.

        Args:
            program: The program, consumed.

        Returns:
            The destination family's carrier of the fiber's handle.
        """
        return Self._Concurrent.start(program^)

    @staticmethod
    def join[T: Movable & Deinitable](var fiber: Self.Handle[T]) -> Self.Joined[T]:
        """Delegate to LiftConcurrent.

        Parameters:
            T: The layer program's success type.

        Args:
            fiber: The handle, consumed.

        Returns:
            The destination family's carrier of the outcome.
        """
        return Self._Concurrent.join[T](fiber^)

    @staticmethod
    def cancel[T: Movable & Deinitable](fiber: Self.Handle[T]) -> Self.Stopped:
        """Delegate to LiftConcurrent.

        Parameters:
            T: The layer program's success type.

        Args:
            fiber: The handle, borrowed.

        Returns:
            The destination family's unit carrier.
        """
        return Self._Concurrent.cancel[T](fiber)

    @staticmethod
    def never[A: Movable & Deinitable]() -> Self.Forever[A]:
        """Delegate to LiftConcurrent.

        Parameters:
            A: The success type the carrier declares.

        Returns:
            The destination family's carrier.
        """
        return Self._Concurrent.never[A]()

    @staticmethod
    def cede() -> Self.Ceded:
        """Delegate to LiftConcurrent.

        Returns:
            The destination family's unit carrier.
        """
        return Self._Concurrent.cede()

    @staticmethod
    def make_ref[T: Movable & Deinitable](var value: T) -> Self.RefMade[T]:
        """Delegate to LiftConcurrent.

        Parameters:
            T: The state type.

        Args:
            value: The initial state, consumed.

        Returns:
            The destination family's carrier of the new cell.
        """
        return Self._Concurrent.make_ref(value^)

    @staticmethod
    def make_deferred[T: Copyable & Deinitable]() -> Self.DeferredMade[T]:
        """Delegate to LiftConcurrent.

        Parameters:
            T: The value type.

        Returns:
            The destination family's carrier of the new deferred value.
        """
        return Self._Concurrent.make_deferred[T]()

    @staticmethod
    def get_ref[T: Copyable & Deinitable](cell: Self.RefHandle[T]) -> Self.RefRead[T]:
        """Delegate to LiftConcurrent.

        Parameters:
            T: The state type.

        Args:
            cell: The cell, borrowed.

        Returns:
            The destination family's carrier of the copy.
        """
        return Self._Concurrent.get_ref[T](cell)

    @staticmethod
    def set_ref[T: Movable & Deinitable](cell: Self.RefHandle[T], var value: T) -> Self.RefWritten:
        """Delegate to LiftConcurrent.

        Parameters:
            T: The state type.

        Args:
            cell: The cell, borrowed.
            value: The replacement, consumed.

        Returns:
            The destination family's unit carrier.
        """
        return Self._Concurrent.set_ref[T](cell, value^)

    @staticmethod
    def update_ref[T: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](cell: Self.RefHandle[T], var function: F) -> Self.RefUpdated[T, F]:
        """Delegate to LiftConcurrent.

        Parameters:
            T: The state type.
            F: A non-raising transformation from T to T.

        Args:
            cell: The cell, borrowed.
            function: The transformation, consumed.

        Returns:
            The destination family's unit carrier.
        """
        return Self._Concurrent.update_ref[T, F](cell, function^)

    @staticmethod
    def modify_ref[T: Movable & Deinitable, A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](cell: Self.RefHandle[T], var function: F) -> Self.RefModified[T, A, F]:
        """Delegate to LiftConcurrent.

        Parameters:
            T: The state type.
            A: The result type.
            F: A non-raising transformation from T to (T, A).

        Args:
            cell: The cell, borrowed.
            function: The transformation, consumed.

        Returns:
            The destination family's carrier of A.
        """
        return Self._Concurrent.modify_ref[T, A, F](cell, function^)

    @staticmethod
    def complete_deferred[T: Copyable & Deinitable](deferred: Self.DeferredHandle[T], var value: T) -> Self.DeferredCompleted:
        """Delegate to LiftConcurrent.

        Parameters:
            T: The value type.

        Args:
            deferred: The deferred value, borrowed.
            value: The value, consumed.

        Returns:
            The destination family's carrier of whether this completion won.
        """
        return Self._Concurrent.complete_deferred[T](deferred, value^)

    @staticmethod
    def get_deferred[T: Copyable & Deinitable](deferred: Self.DeferredHandle[T]) -> Self.DeferredRead[T]:
        """Delegate to LiftConcurrent.

        Parameters:
            T: The value type.

        Args:
            deferred: The deferred value, borrowed.

        Returns:
            The destination family's carrier of the value.
        """
        return Self._Concurrent.get_deferred[T](deferred)

    @staticmethod
    def monotonic() -> Self.Monotonic:
        """Lift the base's clock reading, as LiftTiming does.

        Returns:
            The destination family's carrier of the current Instant.
        """
        return Self._Source.read()

    @staticmethod
    def timed[V: Movable & Deinitable](var program: V) -> Self.Timed[V]:
        """Measure a layer program with the lifted clock reading, as LiftTiming does.

        Parameters:
            V: The program's carrier type.

        Args:
            program: The program, consumed.

        Returns:
            The destination family's carrier of the duration and value.
        """
        comptime assert Self.TimedCompatible[V], "timed: unsupported layer, mismatched base family or program"
        return _timed[Self._Source, V](program^)

    @staticmethod
    def sleep(duration: Duration) -> Self.Slept:
        """Lift the base's sleep.

        Args:
            duration: The duration.

        Returns:
            The destination family's unit carrier.
        """
        comptime assert Self._Selected, "sleep: mismatched base family, or a layer whose programs are not base programs"
        return Self._Source.sleep(duration)

    @staticmethod
    def timeout_to[V: Movable & Deinitable](var program: V, duration: Duration, var fallback: V) -> Self.TimedOut[V]:
        """Forward a layer program and fallback to the base's timeout_to.

        Parameters:
            V: The program's carrier type.

        Args:
            program: The program, consumed.
            duration: The deadline, measured from entry.
            fallback: The fallback, consumed.

        Returns:
            The base's carrier, a carrier of the destination family.
        """
        comptime assert Self.TemporalCompatible[V], "timeout_to: unsupported layer, mismatched base family or program"
        return Self.C.timeout_to(program^, duration, fallback^)

    @staticmethod
    def timeout_after[V: Movable & Deinitable](var program: V, duration: Duration, var fallback: V) -> Self.TimedOut[V]:
        """Forward a layer program and fallback to the base's timeout_after.

        Parameters:
            V: The program's carrier type.

        Args:
            program: The program, consumed.
            duration: The deadline, measured from entry.
            fallback: The fallback, consumed.

        Returns:
            The base's carrier, a carrier of the destination family.
        """
        comptime assert Self.TemporalCompatible[V], "timeout_after: unsupported layer, mismatched base family or program"
        return Self.C.timeout_after(program^, duration, fallback^)

    @staticmethod
    def timeout[V: Movable & Deinitable](var program: V, duration: Duration, var error: Self.Error) -> Self.TimedOut[V]:
        """Forward a layer program to the base's timeout, raising the base's error.

        Parameters:
            V: The program's carrier type.

        Args:
            program: The program, consumed.
            duration: The deadline, measured from entry.
            error: The base's domain error raised on timeout, consumed.

        Returns:
            The base's carrier, a carrier of the destination family.
        """
        comptime assert Self.TemporalCompatible[V], "timeout: unsupported layer, mismatched base family or program"
        return Self.C.timeout(program^, duration, error^)

    @staticmethod
    def delay_by[V: Movable & Deinitable](var program: V, duration: Duration) -> Self.DelayedBy[V]:
        """Sleep through the layer, then run the program.

        Parameters:
            V: The program's carrier type.

        Args:
            program: The program, consumed.
            duration: The sleep before it.

        Returns:
            The destination family's carrier with the program's outcome.
        """
        comptime assert Self.TemporalCompatible[V], "delay_by: unsupported layer, mismatched base family or program"
        return _delay_by[Self._Source, V](program^, duration)

    @staticmethod
    def and_wait[V: Movable & Deinitable](var program: V, duration: Duration) -> Self.Waited[V]:
        """Run the program, then sleep through the layer, keeping its value.

        Parameters:
            V: The program's carrier type.

        Args:
            program: The program, consumed.
            duration: The sleep after it.

        Returns:
            The destination family's carrier with the program's value; a
            layer's absence or stored error skips the sleep.
        """
        comptime assert Self.TemporalCompatible[V], "and_wait: unsupported layer, mismatched base family or program"
        return _and_wait[Self._Source, V](program^, duration)


struct LiftBlocking[I: Monad & _Lifting, C: Blocking](Blocking, not Deinitable):
    """Lift a selected Blocking capability through one transformer.

    Both operations lift the base's carrier, as LiftDefer's delay does, so the
    call runs where the base runs it: on Async's pool, or inline in SyncIO.
    I.Base must equal C.Family.

    Parameters:
        I: The destination transformer family.
        C: The Blocking capability of its immediate base.
    """
    comptime _Layer = downcast[Self.I, _CapabilityLifting]
    comptime _Selected = Self._Layer.Base == Self.C.Family
    comptime Family = Self.I
    comptime BlockingCompatible[F: ThunkContract & Movable & Deinitable] = Self._Selected and Self.C.BlockingCompatible[F] and _ErrorCompatible[Never, Self.I.LiftError[Self.C.Blocked[F]]]
    comptime Blocked[F: ThunkContract & Movable & Deinitable] = Self.I.Lifted[Self.C.Blocked[F]]
    comptime InterruptibleCompatible[F: BorrowCallContract & Movable & Deinitable] = Self._Selected and Self.C.InterruptibleCompatible[F] and _ErrorCompatible[Never, Self.I.LiftError[Self.C.Interrupted[F]]]
    comptime Interrupted[F: BorrowCallContract & Movable & Deinitable] = Self.I.Lifted[Self.C.Interrupted[F]]

    @staticmethod
    def blocking[F: ThunkContract & Movable & Deinitable](var function: F) -> Self.Blocked[F]:
        """Lift the base's blocking call.

        Parameters:
            F: A once-callable thunk the base admits.

        Args:
            function: The function, consumed.

        Returns:
            The destination family's carrier of the function's value.
        """
        comptime assert Self.BlockingCompatible[F], "blocking: unavailable capability or mismatched base family"
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.Blocked[F]]]
        return _lift_as[Never, Self.I](Self.C.blocking(function^))

    @staticmethod
    def interruptible[F: BorrowCallContract & Movable & Deinitable](var function: F) -> Self.Interrupted[F]:
        """Lift the base's interruptible call.

        Parameters:
            F: A once-callable borrowing an Interruption that the base admits.

        Args:
            function: The function, consumed.

        Returns:
            The destination family's carrier of the function's value.
        """
        comptime assert Self.InterruptibleCompatible[F], "interruptible: unavailable capability or mismatched base family"
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.Interrupted[F]]]
        return _lift_as[Never, Self.I](Self.C.interruptible(function^))


def defer[F: ThunkContract & Movable & Deinitable, //, I: Defer](var factory: F) -> I.Deferred[F] where I.DeferCompatible[F]:
    """Build an effect when the program reaches it, in any family with Defer.

    Parameters:
        F: An owned once-callable returning one of the family's carriers.
        I: The capability dictionary, such as Async[E] or SyncIO[E].

    Args:
        factory: The factory, consumed.

    Returns:
        The family's carrier running the effect the factory builds.
    """
    return I.defer(factory^)


def raise_error[I: Raise, A: Movable & Deinitable](var error: I.Error) -> I.Raised[A]:
    """Fail with one ordinary error, in any family with Raise.

    Parameters:
        I: The capability dictionary, such as Async[E] or SyncIO[E].
        A: The success type the carrier declares.

    Args:
        error: The error, consumed.

    Returns:
        The family's carrier failing with an uncanceled failure holding it.
    """
    return I.raise_error[A](error^)


def start[V: Movable & Deinitable, //, I: Spawn](var program: V) -> I.Started[V] where I.StartCompatible[V]:
    """Start a program as a fiber owned by the running fiber, in any family with Spawn.

    Parameters:
        V: The program's carrier type.
        I: The capability dictionary, such as Async[E].

    Args:
        program: The program, consumed.

    Returns:
        The family's carrier producing the fiber's handle.
    """
    return I.start(program^)


def join[I: Spawn, T: Movable & Deinitable](var fiber: I.Handle[T]) -> I.Joined[T]:
    """Wait for a fiber and its cleanup, then take its outcome.

    Parameters:
        I: The capability dictionary, such as Async[E].
        T: The fiber's success type.

    Args:
        fiber: The handle, consumed.

    Returns:
        The family's carrier producing the fiber's outcome.
    """
    return I.join[T](fiber^)


def cancel[I: Spawn, T: Movable & Deinitable](fiber: I.Handle[T]) -> I.Stopped:
    """Cancel a fiber and wait for it to finish, without its outcome.

    Parameters:
        I: The capability dictionary, such as Async[E].
        T: The fiber's success type.

    Args:
        fiber: The handle, borrowed.

    Returns:
        The family's unit carrier completing after the fiber terminates.
    """
    return I.cancel[T](fiber)


def never[I: Spawn, A: Movable & Deinitable]() -> I.Forever[A]:
    """Wait until canceled, in any family with Spawn.

    Parameters:
        I: The capability dictionary, such as Async[E].
        A: The success type the carrier declares.

    Returns:
        The family's carrier that never produces a value.
    """
    return I.never[A]()


def cede[I: Spawn]() -> I.Ceded:
    """Yield to other runnable work once, in any family with Spawn.

    Parameters:
        I: The capability dictionary, such as Async[E].

    Returns:
        The family's unit carrier.
    """
    return I.cede()


def make_ref[T: Movable & Deinitable, //, I: Concurrent](var value: T) -> I.RefMade[T]:
    """Create a shared cell when the program reaches it, in any family with Concurrent.

    Parameters:
        T: The state type.
        I: The capability dictionary, such as Async[E].

    Args:
        value: The initial state, consumed.

    Returns:
        The family's carrier producing a new cell on each run.
    """
    return I.make_ref(value^)


def make_deferred[I: Concurrent, T: Copyable & Deinitable]() -> I.DeferredMade[T]:
    """Create an empty single-assignment value when the program reaches it.

    Parameters:
        I: The capability dictionary, such as Async[E].
        T: The value type, copied for every reader.

    Returns:
        The family's carrier producing a new deferred value on each run.
    """
    return I.make_deferred[T]()


def get_ref[I: Concurrent, T: Copyable & Deinitable](cell: I.RefHandle[T]) -> I.RefRead[T]:
    """Copy a cell's state, in any family with Concurrent.

    Parameters:
        I: The capability dictionary, such as Async[E].
        T: The state type.

    Args:
        cell: The cell, borrowed.

    Returns:
        The family's carrier producing the copy.
    """
    return I.get_ref[T](cell)


def set_ref[T: Movable & Deinitable, //, I: Concurrent](cell: I.RefHandle[T], var value: T) -> I.RefWritten:
    """Replace a cell's state, in any family with Concurrent.

    Parameters:
        T: The state type.
        I: The capability dictionary, such as Async[E].

    Args:
        cell: The cell, borrowed.
        value: The replacement, consumed.

    Returns:
        The family's unit carrier.
    """
    return I.set_ref[T](cell, value^)


def update_ref[T: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, //, I: Concurrent](cell: I.RefHandle[T], var function: F) -> I.RefUpdated[T, F] where I.UpdateCompatible[T, F]:
    """Transform a cell's state atomically, in any family with Concurrent.

    Parameters:
        T: The state type.
        F: An owned non-raising transformation from T to T.
        I: The capability dictionary, such as Async[E].

    Args:
        cell: The cell, borrowed.
        function: The transformation, consumed.

    Returns:
        The family's unit carrier.
    """
    return I.update_ref[T, F](cell, function^)


def update_ref[T: Movable & Deinitable, //, I: Concurrent](cell: I.RefHandle[T], function: def(var _NativeOwnedArg[T]) thin -> T
) -> I.RefUpdated[T, NativeUnary[T, T, Never, def(var _NativeOwnedArg[T]) thin -> T, False]] where I.UpdateCompatible[T, NativeUnary[T, T, Never, def(var _NativeOwnedArg[T]) thin -> T, False]]:
    """Transform a cell's state with a plain function; closures are rejected."""
    return I.update_ref[T, NativeUnary[T, T, Never, def(var _NativeOwnedArg[T]) thin -> T, False]](cell, NativeUnary[T, T, Never, def(var _NativeOwnedArg[T]) thin -> T, False](function))


def modify_ref[T: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, //, I: Concurrent, A: Movable & Deinitable](cell: I.RefHandle[T], var function: F) -> I.RefModified[T, A, F] where I.ModifyCompatible[T, A, F]:
    """Consume and replace a cell's state atomically, producing a result.

    Parameters:
        T: The state type.
        F: An owned non-raising transformation from T to (T, A).
        I: The capability dictionary, such as Async[E].
        A: The result type.

    Args:
        cell: The cell, borrowed.
        function: The transformation, consumed.

    Returns:
        The family's carrier producing A.
    """
    return I.modify_ref[T, A, F](cell, function^)


def modify_ref[T: Movable & Deinitable, //, I: Concurrent, A: Movable & Deinitable](cell: I.RefHandle[T], function: def(var _NativeOwnedArg[T]) thin -> Tuple[T, A]
) -> I.RefModified[T, A, NativeUnary[T, Tuple[T, A], Never, def(var _NativeOwnedArg[T]) thin -> Tuple[T, A], False]] where I.ModifyCompatible[T, A, NativeUnary[T, Tuple[T, A], Never, def(var _NativeOwnedArg[T]) thin -> Tuple[T, A], False]]:
    """Modify a cell's state with a plain function; spell modify_ref[I, A]. Closures are rejected."""
    return I.modify_ref[T, A, NativeUnary[T, Tuple[T, A], Never, def(var _NativeOwnedArg[T]) thin -> Tuple[T, A], False]](cell, NativeUnary[T, Tuple[T, A], Never, def(var _NativeOwnedArg[T]) thin -> Tuple[T, A], False](function))


def complete_deferred[T: Copyable & Deinitable, //, I: Concurrent](deferred: I.DeferredHandle[T], var value: T) -> I.DeferredCompleted:
    """Assign a deferred value once, in any family with Concurrent.

    Parameters:
        T: The value type.
        I: The capability dictionary, such as Async[E].

    Args:
        deferred: The deferred value, borrowed.
        value: The value, consumed.

    Returns:
        The family's carrier producing whether this completion won.
    """
    return I.complete_deferred[T](deferred, value^)


def get_deferred[I: Concurrent, T: Copyable & Deinitable](deferred: I.DeferredHandle[T]) -> I.DeferredRead[T]:
    """Wait for a deferred value, unless canceled, in any family with Concurrent.

    Parameters:
        I: The capability dictionary, such as Async[E].
        T: The value type.

    Args:
        deferred: The deferred value, borrowed.

    Returns:
        The family's carrier producing a copy of the value.
    """
    return I.get_deferred[T](deferred)


def monotonic[I: Timing]() -> I.Monotonic:
    """Read the inherited clock when the program reaches it, in any family with Timing.

    Parameters:
        I: The capability dictionary, such as Async[E] or SyncIO[E].

    Returns:
        The family's carrier producing the current Instant.
    """
    return I.monotonic()


def timed[V: Movable & Deinitable, //, I: Timing](var program: V) -> I.Timed[V] where I.TimedCompatible[V]:
    """Run a program and measure it on the inherited clock, in any family with Timing.

    Parameters:
        V: The program's carrier type.
        I: The capability dictionary, such as Async[E] or SyncIO[E].

    Args:
        program: The program, consumed.

    Returns:
        The family's carrier producing the elapsed Duration with the value.
    """
    return I.timed(program^)


def sleep[I: Temporal](duration: Duration) -> I.Slept:
    """Wait for a duration on the inherited clock, in any family with Temporal.

    Parameters:
        I: The capability dictionary, such as Async[E].

    Args:
        duration: The duration.

    Returns:
        The family's unit carrier.
    """
    return I.sleep(duration)


def timeout_to[V: Movable & Deinitable, //, I: Temporal](var program: V, duration: Duration, var fallback: V) -> I.TimedOut[V] where I.TemporalCompatible[V]:
    """Fall back after a duration, preferring the program's drained result.

    Parameters:
        V: The program's carrier type.
        I: The capability dictionary, such as Async[E].

    Args:
        program: The program, consumed.
        duration: The deadline, measured from entry.
        fallback: Runs if the deadline passes first, consumed.

    Returns:
        The family's carrier with the program's or the fallback's outcome.
    """
    return I.timeout_to(program^, duration, fallback^)


def timeout_after[V: Movable & Deinitable, //, I: Temporal](var program: V, duration: Duration, var fallback: V) -> I.TimedOut[V] where I.TemporalCompatible[V]:
    """Fall back after a duration by first terminal outcome.

    Parameters:
        V: The program's carrier type.
        I: The capability dictionary, such as Async[E].

    Args:
        program: The program, consumed.
        duration: The deadline, measured from entry.
        fallback: Runs if the deadline passes first, consumed.

    Returns:
        The family's carrier with the program's or the fallback's outcome.
    """
    return I.timeout_after(program^, duration, fallback^)


def timeout[V: Movable & Deinitable, //, I: Temporal](var program: V, duration: Duration, var error: I.Error) -> I.TimedOut[V] where I.TemporalCompatible[V]:
    """Fail with an error after a duration, preferring the program's drained result.

    Parameters:
        V: The program's carrier type.
        I: The capability dictionary, such as Async[E].

    Args:
        program: The program, consumed.
        duration: The deadline, measured from entry.
        error: The domain error raised on timeout, consumed.

    Returns:
        The family's carrier with the program's outcome or the error.
    """
    return I.timeout(program^, duration, error^)


def delay_by[V: Movable & Deinitable, //, I: Temporal](var program: V, duration: Duration) -> I.DelayedBy[V] where I.TemporalCompatible[V]:
    """Sleep, then run the program, in any family with Temporal.

    Parameters:
        V: The program's carrier type.
        I: The capability dictionary, such as Async[E].

    Args:
        program: The program, consumed.
        duration: The sleep before it.

    Returns:
        The family's carrier with the program's outcome.
    """
    return I.delay_by(program^, duration)


def and_wait[V: Movable & Deinitable, //, I: Temporal](var program: V, duration: Duration) -> I.Waited[V] where I.TemporalCompatible[V]:
    """Run the program, then sleep, keeping its value, in any family with Temporal.

    Parameters:
        V: The program's carrier type.
        I: The capability dictionary, such as Async[E].

    Args:
        program: The program, consumed.
        duration: The sleep after it.

    Returns:
        The family's carrier with the program's value after the sleep.
    """
    return I.and_wait(program^, duration)


def blocking[F: ThunkContract & Movable & Deinitable, //, I: Blocking](var function: F) -> I.Blocked[F] where I.BlockingCompatible[F]:
    """Run a blocking function, in any family with Blocking.

    Async runs it on the root's blocking pool and SyncIO inline; neither can
    cancel it. Other overloads take a plain native function; closures are
    rejected.

    Parameters:
        F: An owned once-callable thunk the family admits.
        I: The capability dictionary, such as Async[E] or SyncIO[E].

    Args:
        function: The function, consumed.

    Returns:
        The family's carrier producing the function's value.
    """
    return I.blocking(function^)


def blocking[R: Movable & Deinitable, //, I: Blocking](function: def() thin -> R) -> I.Blocked[_NativeThunk[R, Never, def() thin -> R, False]] where I.BlockingCompatible[_NativeThunk[R, Never, def() thin -> R, False]]:
    """Run a plain native blocking function, in any family with Blocking."""
    return I.blocking(_NativeThunk[R, Never, def() thin -> R, False](function))


def blocking[R: Movable & Deinitable, X: Movable & Deinitable, //, I: Blocking](function: def() raises X thin -> R) -> I.Blocked[_NativeThunk[R, X, def() raises X thin -> R, True]] where I.BlockingCompatible[_NativeThunk[R, X, def() raises X thin -> R, True]]:
    """Run a raising plain native blocking function, in any family with Blocking."""
    return I.blocking(_NativeThunk[R, X, def() raises X thin -> R, True](function))


def interruptible[F: BorrowCallContract & Movable & Deinitable, //, I: Blocking](var function: F) -> I.Interrupted[F] where I.InterruptibleCompatible[F]:
    """Run a function that observes cancellation through an Interruption, in any family with Blocking.

    Async runs it on the root's blocking pool, and cancellation completes when
    it returns; SyncIO runs it inline with a handle reading the program's
    token. Other overloads take a plain native function; closures are rejected.

    Parameters:
        F: An owned once-callable borrowing an Interruption that the family admits.
        I: The capability dictionary, such as Async[E] or SyncIO[E].

    Args:
        function: The function, consumed.

    Returns:
        The family's carrier producing the function's value.
    """
    return I.interruptible(function^)


def interruptible[R: Movable & Deinitable, //, I: Blocking](function: def(Interruption) thin -> R) -> I.Interrupted[_NativeBorrow[Interruption, R, Never, def(Interruption) thin -> R, False]] where I.InterruptibleCompatible[_NativeBorrow[Interruption, R, Never, def(Interruption) thin -> R, False]]:
    """Run a plain native interruptible function, in any family with Blocking."""
    return I.interruptible(_NativeBorrow[Interruption, R, Never, def(Interruption) thin -> R, False](function))


def interruptible[R: Movable & Deinitable, X: Movable & Deinitable, //, I: Blocking](function: def(Interruption) raises X thin -> R) -> I.Interrupted[_NativeBorrow[Interruption, R, X, def(Interruption) raises X thin -> R, True]] where I.InterruptibleCompatible[_NativeBorrow[Interruption, R, X, def(Interruption) raises X thin -> R, True]]:
    """Run a raising plain native interruptible function, in any family with Blocking."""
    return I.interruptible(_NativeBorrow[Interruption, R, X, def(Interruption) raises X thin -> R, True](function))
