"""Explicit, compile-time selections of environment and state capabilities."""
from std.builtin.rebind import downcast
from fp.algebra.protocols import Monad, _Lifting, _SemigroupBinary
from fp.callables._binding import _BindSecond
from fp.callables.protocols import BorrowCallContract, UnaryContract, OnceUnary, ThunkContract
from fp.callables.native import _NativeBorrow, _Borrowing, _RaisingBorrowing, NativeUnary, as_unary, _Unary, _RaisingUnary
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error
from .protocols import Ask, Local, Stateful, Tell, Listen, Censor, Defer, Raise, Spawn, _Hoisting, _CapabilityLifting, _LocalLifting
from ._adapt import _lift_as
from ._transport import _CensorOp


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


def local[V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable, //, I: Local](var f: F, var value: V
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
        f: The environment transformation, consumed.
        value: The computation, consumed.

    Returns:
        The scoped carrier, preserving payload, origins and deferred execution.

    Raises:
        The capability's native construction error, separate from execution.
    """
    return I.local(f^, value^)


def local[V: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, //, I: Local, F: _Borrowing[P, R]](var f: F, var value: V
) raises I.LocalError[V, _NativeBorrow[P, R, Never, F, False]] -> I.Localized[V, _NativeBorrow[P, R, Never, F, False]] where I.LocalCompatible[V] and P == I.Environment and R == I.Environment:
    """Scope with an owned native borrowing function or closure."""
    return local[I](_NativeBorrow[P, R, Never, F, False](f^), value^)


def local[V: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, E: Movable & Deinitable, //, I: Local, F: _RaisingBorrowing[P, R, E]](var f: F, var value: V
) raises I.LocalError[V, _NativeBorrow[P, R, E, F, True]] -> I.Localized[V, _NativeBorrow[P, R, E, F, True]] where I.LocalCompatible[V] and P == I.Environment and R == I.Environment:
    """Scope with a raising native callback; keep its exact error type."""
    return local[I](_NativeBorrow[P, R, E, F, True](f^), value^)


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


def censor[F: UnaryContract & Movable & Deinitable, V: Movable & Deinitable, //, I: Censor](var f: F, var value: V
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
        f: The log transformation, consumed.
        value: The computation, consumed.

    Returns:
        A Family carrier preserving payload and native origins.

    Raises:
        The native construction error; execution errors stay native.
    """
    return I.censor(f^, value^)


def censor[A: Movable & Deinitable, R: Movable & Deinitable, V: Movable & Deinitable, //, I: Censor, F: _Unary[A, R]](var f: F, var value: V
) raises I.CensorError[V, NativeUnary[A, R, Never, F, False]] -> I.Censored[V, NativeUnary[A, R, Never, F, False]] where I.CensorCompatible[V, NativeUnary[A, R, Never, F, False]] and A == I.Log.Value and R == I.Log.Value:
    """Scope the selected log with an owned native consuming callback."""
    return censor[I](as_unary(f^), value^)


def censor[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, V: Movable & Deinitable, //, I: Censor, F: _RaisingUnary[A, R, E]](var f: F, var value: V
) raises I.CensorError[V, NativeUnary[A, R, E, F, True]] -> I.Censored[V, NativeUnary[A, R, E, F, True]] where I.CensorCompatible[V, NativeUnary[A, R, E, F, True]] and A == I.Log.Value and R == I.Log.Value:
    """Scope the selected log with a raising native callback; keep its error."""
    return censor[I](as_unary(f^), value^)


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
