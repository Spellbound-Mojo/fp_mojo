"""Effectful function composition, lowered to the ordinary composition engine."""
from std.builtin.rebind import downcast, rebind_var
from fp.algebra.protocols import Monad
from fp.algebra._primitive_contracts import MapContract, BindContract
from fp.algebra._admission import _CarrierCompatible
from fp.callables._views import _UnaryViewable
from fp.callables.protocols import UnaryContract, Unary, MutableUnary, OnceUnary
from fp.callables.invoke import call_once, RepeatableUnary
from fp.callables.native import as_unary, NativeUnary, _Unary, _RaisingUnary
from fp.callables._receiver import _SharedUnaryRef, _MutableUnaryRef
from .composition import Composition
from ._stages import _stage_once
from fp.algebra._adapt import _map_as, _flat_map_as
from fp._internal.errors import _ErrorCompatible
from std.reflection import reflect


# Native field projections, exactly as produced by origin_of(value.field).
# Pointer construction below verifies every projected origin against its field;
# no origin cast or untracked pointer participates in this representation.
comptime _FunctionOrigin[o: Origin] = Origin[_mlir_origin=__mlir_attr[
    `#lit.origin.field<`, o._mlir_origin, `, "function"> : `, type_of(o._mlir_origin)
]]()
comptime _LeftOrigin[o: Origin] = Origin[_mlir_origin=__mlir_attr[
    `#lit.origin.field<`, o._mlir_origin, `, "left"> : `, type_of(o._mlir_origin)
]]()
comptime _RightOrigin[o: Origin] = Origin[_mlir_origin=__mlir_attr[
    `#lit.origin.field<`, o._mlir_origin, `, "right"> : `, type_of(o._mlir_origin)
]]()
comptime _ProgramOrigin[o: Origin] = Origin[_mlir_origin=__mlir_attr[
    `#lit.origin.field<`, o._mlir_origin, `, "_program"> : `, type_of(o._mlir_origin)
]]()


trait _Program(Movable, Deinitable):
    # Each view is an ordinary callable. The shared/exclusive output may retain
    # the receiver's origin when a family defers its callback.
    comptime Owned: UnaryContract & Movable & Deinitable
    comptime Shared[o: ImmOrigin]: UnaryContract & Movable & Deinitable
    comptime Exclusive[o: MutOrigin]: UnaryContract & Movable & Deinitable
    comptime CanShare: Bool
    comptime CanMutate: Bool
    def owned(deinit self) -> Self.Owned: ...
    def shared[o: ImmOrigin](ref[o] self) -> Self.Shared[o]: ...
    def exclusive[o: MutOrigin](ref[o] self) -> Self.Exclusive[o]: ...


@fieldwise_init
struct _Leaf[F: UnaryContract & Movable & Deinitable](_Program, Copyable where conforms_to(F, Copyable)):
    var function: Self.F
    comptime Owned = Self.F
    comptime Shared[o: ImmOrigin] = _SharedUnaryRef[downcast[Self.F, Unary], o]
    comptime Exclusive[o: MutOrigin] = _MutableUnaryRef[Self.F, _FunctionOrigin[o]]
    comptime CanShare = conforms_to(Self.F, Unary)
    comptime CanMutate = RepeatableUnary[Self.F]
    def owned(deinit self) -> Self.Owned:
        return self.function^
    def shared[o: ImmOrigin](ref[o] self) -> Self.Shared[o]:
        comptime assert Self.CanShare, "kleisli: a shared call requires shared callbacks"
        ref function = rebind[downcast[Self.F, Unary]](reflect[Self].field_ref[0](self))
        return Self.Shared[o](Pointer(to=function))
    def exclusive[o: MutOrigin](ref[o] self) -> Self.Exclusive[o]:
        comptime assert Self.CanMutate, "kleisli: a mutable call requires repeatable callbacks"
        return Self.Exclusive[o](Pointer(to=self.function))


@fieldwise_init
struct _EffectStage[I: Monad, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, bind: Bool](OnceUnary):
    """Adapt a payload callback to a carrier stage; the family owns execution."""
    var function: Self.F
    comptime Arg = Self.V
    comptime _Map = MapContract[Self.I,Self.V,Self.F]
    comptime _Bind = BindContract[Self.I,Self.V,Self.F]
    comptime Out = Self._Bind.Out if Self.bind else Self._Map.Out
    comptime Error = Self._Bind.Error if Self.bind else Self._Map.Error
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime if Self.bind:
            comptime assert Self.Out == Self.I.Bound[Self.V, Self.F] and _ErrorCompatible[Self.Error, Self.I.BindError[Self.V, Self.F]]
            return rebind_var[Self.Out](_flat_map_as[Self.Error, Self.I](self.function^, arg^))
        else:
            comptime assert Self.Out == Self.I.Mapped[Self.V, Self.F] and _ErrorCompatible[Self.Error, Self.I.MapError[Self.V, Self.F]]
            return rebind_var[Self.Out](_map_as[Self.Error, Self.I](self.function^, arg^))


# mode 0: ordinary input composition; 1: effectful output; 2: mapped output.
comptime _Tail[I: Monad, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, mode: Int]: UnaryContract & Movable & Deinitable = F if mode == 0 else _EffectStage[I, V, F, mode == 1]


def _tail[I: Monad, V: Movable & Deinitable, mode: Int, F: UnaryContract & Movable & Deinitable](var f: F) -> _Tail[I, V, F, mode]:
    comptime if mode == 0:
        comptime assert _Tail[I, V, F, mode] == F
        return rebind_var[_Tail[I, V, F, mode]](f^)
    else:
        comptime assert _Tail[I, V, F, mode] == _EffectStage[I, V, F, mode == 1]
        return rebind_var[_Tail[I, V, F, mode]](_EffectStage[I, V, F, mode == 1](f^))


# Keep L and R independent at this boundary. Deriving the right effect-stage
# type while borrowing the left field directly gives it a phantom input-origin
# dependency on Mojo 1.1, preventing otherwise disjoint mutable field borrows.
def _compose_steps[I: Monad, mode: Int, L: UnaryContract & Movable & Deinitable, R: UnaryContract & Movable & Deinitable](var left: L, var right: R) -> Composition[False, 1, L, _Tail[I, L.Out, R, mode]]:
    return Composition[False, 1, L, _Tail[I, L.Out, R, mode]](left^, _tail[I, L.Out, mode](right^))


@fieldwise_init
struct _Join[I: Monad, L: _Program, R: _Program, mode: Int](_Program, Copyable where conforms_to(L, Copyable) and conforms_to(R, Copyable)):
    var left: Self.L
    var right: Self.R
    comptime Owned = Composition[False, 1, Self.L.Owned, _Tail[Self.I, Self.L.Owned.Out, Self.R.Owned, Self.mode]]
    comptime Shared[o: ImmOrigin] = Composition[False, 1, Self.L.Shared[o], _Tail[Self.I, Self.L.Shared[o].Out, Self.R.Shared[o], Self.mode]]
    comptime Exclusive[o: MutOrigin] = Composition[False, 1, Self.L.Exclusive[_LeftOrigin[o]], _Tail[Self.I, Self.L.Exclusive[_LeftOrigin[o]].Out, Self.R.Exclusive[_RightOrigin[o]], Self.mode]]
    comptime CanShare = Self.L.CanShare and Self.R.CanShare
    comptime CanMutate = Self.L.CanMutate and Self.R.CanMutate
    def owned(deinit self) -> Self.Owned:
        return _compose_steps[Self.I, Self.mode](self.left^.owned(), self.right^.owned())
    def shared[o: ImmOrigin](ref[o] self) -> Self.Shared[o]:
        ref left = rebind[Self.L](reflect[Self].field_ref[0](self))
        ref right = rebind[Self.R](reflect[Self].field_ref[1](self))
        return _compose_steps[Self.I, Self.mode](left.shared[o](), right.shared[o]())
    def exclusive[o: MutOrigin](ref[o] self) -> Self.Exclusive[o]:
        return _compose_steps[Self.I, Self.mode](self.left.exclusive(), self.right.exclusive())


trait _KleisliValue:
    comptime _Family: Monad


@fieldwise_init
struct Kleisli[I: Monad, P: _Program](_KleisliValue, OnceUnary, _UnaryViewable where P.CanShare, Copyable where conforms_to(P, Copyable)):
    """A stored function returning an effect of family `I`, made by `kleisli`.

    Chaining only stores callbacks. `then` sequences through the family's bind,
    `map` transforms successful payloads, `compose` prepends an effectful stage,
    and `contramap` prepends an ordinary input transformation. All consume the
    previous chain and their callback; use an explicit copy to keep a chain.

    Shared and mutable calls borrow the callbacks. A deferred result retains
    that borrow until it finishes. `call_once` transfers the callbacks to the
    result and implements the library's `OnceUnary` protocol. No callback or
    payload is copied implicitly.

    Parameters:
        I: The Monad family governing sequencing and errors.
        P: The inferred stored program; use the factory to construct one.
    """
    var _program: Self.P
    comptime _Family = Self.I
    comptime Arg = Self.P.Owned.Arg
    comptime Out = Self.P.Owned.Out
    comptime Error = Self.P.Owned.Error

    comptime _View[o: ImmOrigin] = _KleisliView[Self.I, Self.P, o]

    def _unary_view[o: ImmOrigin](ref[o] self) -> Self._View[o]:
        comptime assert Self.P.CanShare, "kleisli: a shared callback requires shared stages"
        return Self._View[o](Pointer(to=self))

    def _into_program(deinit self) -> Self.P:
        return self._program^

    def call[o: ImmOrigin](ref[o] self, var arg: Self.Arg) raises Self.P.Shared[o].Error -> Self.P.Shared[o].Out:
        """Call shared callbacks, retaining a borrow if the effect defers them.

        Parameters:
            o: The shared receiver origin, retained by deferred results.

        Args:
            arg: The input value, consumed.

        Returns:
            The family's effect, possibly borrowing this chain.

        Raises:
            The exact combined native error of the callbacks and family operations.
        """
        comptime assert Self.P.CanShare, "kleisli: a shared call requires shared callbacks"
        comptime assert Self.P.Shared[o].Arg == Self.Arg
        ref program = rebind[Self.P](reflect[Self].field_ref[0](self))
        return call_once(program.shared[o](), rebind_var[Self.P.Shared[o].Arg](arg^))

    def call_mut[o: MutOrigin](ref[o] self, var arg: Self.Arg) raises Self.P.Exclusive[_ProgramOrigin[o]].Error -> Self.P.Exclusive[_ProgramOrigin[o]].Out:
        """Call repeatable callbacks with exclusive access; state persists.

        Parameters:
            o: The mutable receiver origin, retained by deferred results.

        Args:
            arg: The input value, consumed.

        Returns:
            The family's effect, possibly retaining mutable callback references.

        Raises:
            The exact combined native error of the callbacks and family operations.
        """
        comptime assert Self.P.CanMutate, "kleisli: a mutable call requires repeatable callbacks"
        comptime assert Self.P.Exclusive[_ProgramOrigin[o]].Arg == Self.Arg
        var stage = Optional(self._program.exclusive())
        return _stage_once[Self.P.Exclusive[_ProgramOrigin[o]].Out, Self.P.Exclusive[_ProgramOrigin[o]].Error](stage, arg^)

    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        """Consume the chain, transferring retained callbacks into the effect.

        Args:
            arg: The input value, consumed.

        Returns:
            The family's effect with ownership of any retained callbacks.

        Raises:
            The exact combined native error of the callbacks and family operations.
        """
        return call_once(self._program^.owned(), arg^)

    def then[F: UnaryContract & Movable & Deinitable](deinit self, var function: F) -> Kleisli[Self.I, _Join[Self.I, Self.P, _Leaf[F], 1]] where not conforms_to(F, _KleisliValue) and _CarrierCompatible[Self.I, Self.Out] and Self.I.Element[Self.Out] == F.Arg and _CarrierCompatible[Self.I, F.Out]:
        """Append an effectful callback.

        Parameters:
            F: The callback type, preserving receiver modes, origins and errors.

        Args:
            function: The callback, consumed without calling it.

        Returns:
            A chain that binds each successful payload through the callback.
        """
        return Kleisli[Self.I, _Join[Self.I, Self.P, _Leaf[F], 1]](_Join[Self.I, Self.P, _Leaf[F], 1](self._program^, _Leaf(function^)))

    def then[A: Movable & Deinitable, R: Movable & Deinitable, //, F: _Unary[A, R]](deinit self, var function: F) -> Kleisli[Self.I, _Join[Self.I, Self.P, _Leaf[NativeUnary[A, R, Never, F, False]], 1]] where _CarrierCompatible[Self.I, Self.Out] and Self.I.Element[Self.Out] == A and _CarrierCompatible[Self.I, R]:
        """Append an effectful callback."""
        return self^.then(as_unary(function^))

    def then[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: _RaisingUnary[A, R, E]](deinit self, var function: F) -> Kleisli[Self.I, _Join[Self.I, Self.P, _Leaf[NativeUnary[A, R, E, F, True]], 1]] where _CarrierCompatible[Self.I, Self.Out] and Self.I.Element[Self.Out] == A and _CarrierCompatible[Self.I, R]:
        """Append an effectful callback."""
        return self^.then(as_unary(function^))

    def then[Q: _Program](deinit self, var other: Kleisli[Self.I, Q]) -> Kleisli[Self.I, _Join[Self.I, Self.P, Q, 1]] where _CarrierCompatible[Self.I, Self.Out] and Self.I.Element[Self.Out] == Q.Owned.Arg and _CarrierCompatible[Self.I, Q.Owned.Out]:
        """Compose another Kleisli of the same family, retaining its receiver modes."""
        return Kleisli[Self.I, _Join[Self.I, Self.P, Q, 1]](_Join[Self.I, Self.P, Q, 1](self._program^, other^._into_program()))

    def map[F: UnaryContract & Movable & Deinitable](deinit self, var function: F) -> Kleisli[Self.I, _Join[Self.I, Self.P, _Leaf[F], 2]] where _CarrierCompatible[Self.I, Self.Out] and Self.I.Element[Self.Out] == F.Arg:
        """Map the effect payload through an ordinary callback.

        Parameters:
            F: The callback type, preserving receiver modes, origins and errors.

        Args:
            function: The callback, consumed without calling it.

        Returns:
            A chain that maps the callback over the successful effect payload.
        """
        return Kleisli[Self.I, _Join[Self.I, Self.P, _Leaf[F], 2]](_Join[Self.I, Self.P, _Leaf[F], 2](self._program^, _Leaf(function^)))

    def map[A: Movable & Deinitable, R: Movable & Deinitable, //, F: _Unary[A, R]](deinit self, var function: F) -> Kleisli[Self.I, _Join[Self.I, Self.P, _Leaf[NativeUnary[A, R, Never, F, False]], 2]] where _CarrierCompatible[Self.I, Self.Out] and Self.I.Element[Self.Out] == A:
        """Map the effect payload through an ordinary callback."""
        return self^.map(as_unary(function^))

    def map[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: _RaisingUnary[A, R, E]](deinit self, var function: F) -> Kleisli[Self.I, _Join[Self.I, Self.P, _Leaf[NativeUnary[A, R, E, F, True]], 2]] where _CarrierCompatible[Self.I, Self.Out] and Self.I.Element[Self.Out] == A:
        """Map the effect payload through an ordinary callback."""
        return self^.map(as_unary(function^))

    def compose[F: UnaryContract & Movable & Deinitable](deinit self, var function: F) -> Kleisli[Self.I, _Join[Self.I, _Leaf[F], Self.P, 1]] where not conforms_to(F, _KleisliValue) and _CarrierCompatible[Self.I, Self.Out] and Self.I.Element[F.Out] == Self.Arg and _CarrierCompatible[Self.I, F.Out]:
        """Prepend an effectful callback.

        Parameters:
            F: The callback type, preserving receiver modes, origins and errors.

        Args:
            function: The callback, consumed without calling it.

        Returns:
            A chain that runs the callback first, then binds into this computation.
        """
        return Kleisli[Self.I, _Join[Self.I, _Leaf[F], Self.P, 1]](_Join[Self.I, _Leaf[F], Self.P, 1](_Leaf(function^), self._program^))

    def compose[A: Movable & Deinitable, R: Movable & Deinitable, //, F: _Unary[A, R]](deinit self, var function: F) -> Kleisli[Self.I, _Join[Self.I, _Leaf[NativeUnary[A, R, Never, F, False]], Self.P, 1]] where _CarrierCompatible[Self.I, Self.Out] and Self.I.Element[R] == Self.Arg and _CarrierCompatible[Self.I, R]:
        """Prepend an effectful callback."""
        return self^.compose(as_unary(function^))

    def compose[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: _RaisingUnary[A, R, E]](deinit self, var function: F) -> Kleisli[Self.I, _Join[Self.I, _Leaf[NativeUnary[A, R, E, F, True]], Self.P, 1]] where _CarrierCompatible[Self.I, Self.Out] and Self.I.Element[R] == Self.Arg and _CarrierCompatible[Self.I, R]:
        """Prepend an effectful callback."""
        return self^.compose(as_unary(function^))

    def compose[Q: _Program](deinit self, var other: Kleisli[Self.I, Q]) -> Kleisli[Self.I, _Join[Self.I, Q, Self.P, 1]] where _CarrierCompatible[Self.I, Self.Out] and Self.I.Element[Q.Owned.Out] == Self.Arg and _CarrierCompatible[Self.I, Q.Owned.Out]:
        """Compose another Kleisli of the same family, retaining its receiver modes."""
        return Kleisli[Self.I, _Join[Self.I, Q, Self.P, 1]](_Join[Self.I, Q, Self.P, 1](other^._into_program(), self._program^))

    def contramap[F: UnaryContract & Movable & Deinitable](deinit self, var function: F) -> Kleisli[Self.I, _Join[Self.I, _Leaf[F], Self.P, 0]] where _CarrierCompatible[Self.I, Self.Out] and F.Out == Self.Arg:
        """Transform the input before this computation.

        Parameters:
            F: The callback type, preserving receiver modes, origins and errors.

        Args:
            function: The callback, consumed without calling it.

        Returns:
            A chain that transforms its input before entering this computation.
        """
        return Kleisli[Self.I, _Join[Self.I, _Leaf[F], Self.P, 0]](_Join[Self.I, _Leaf[F], Self.P, 0](_Leaf(function^), self._program^))

    def contramap[A: Movable & Deinitable, R: Movable & Deinitable, //, F: _Unary[A, R]](deinit self, var function: F) -> Kleisli[Self.I, _Join[Self.I, _Leaf[NativeUnary[A, R, Never, F, False]], Self.P, 0]] where _CarrierCompatible[Self.I, Self.Out] and R == Self.Arg:
        """Transform the input before this computation."""
        return self^.contramap(as_unary(function^))

    def contramap[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: _RaisingUnary[A, R, E]](deinit self, var function: F) -> Kleisli[Self.I, _Join[Self.I, _Leaf[NativeUnary[A, R, E, F, True]], Self.P, 0]] where _CarrierCompatible[Self.I, Self.Out] and R == Self.Arg:
        """Transform the input before this computation."""
        return self^.contramap(as_unary(function^))


@fieldwise_init
struct _KleisliView[I: Monad, P: _Program, o: ImmOrigin](Unary, ImplicitlyCopyable):
    var chain: Pointer[Kleisli[Self.I, Self.P], Self.o]
    comptime Arg = Self.P.Owned.Arg
    comptime Out = Self.P.Shared[Self.o].Out
    comptime Error = Self.P.Shared[Self.o].Error
    def call(self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        return self.chain[].call(arg^)


def kleisli[I: Monad, F: UnaryContract & Movable & Deinitable](var function: F) -> Kleisli[I, _Leaf[F]] where _CarrierCompatible[I, F.Out]:
    """Store an effectful callback, with sequencing selected by family `I`.

    Parameters:
        I: The Monad family of the returned effect.
        F: The callback's inferred type, including native origins and errors.

    Args:
        function: The callback, consumed without calling or copying it.

    Returns:
        A stored chain supporting `then`, `map`, `compose` and `contramap`.
    """
    return Kleisli[I, _Leaf[F]](_Leaf(function^))

def kleisli[A: Movable & Deinitable, R: Movable & Deinitable, //, I: Monad, F: _Unary[A, R]](var function: F) -> Kleisli[I, _Leaf[NativeUnary[A, R, Never, F, False]]] where _CarrierCompatible[I, R]:
    """Store a native function or closure, preserving its signature and captures."""
    return kleisli[I](as_unary(function^))

def kleisli[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, I: Monad, F: _RaisingUnary[A, R, E]](var function: F) -> Kleisli[I, _Leaf[NativeUnary[A, R, E, F, True]]] where _CarrierCompatible[I, R]:
    """Store a native function or closure, preserving its signature and captures."""
    return kleisli[I](as_unary(function^))
