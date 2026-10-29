"""Concrete family metadata and adapters over the canonical async machines."""
from std.builtin.rebind import downcast, rebind_var
from fp.algebra.protocols import Functor, Monad, ErrorRecovery, _FamilyCarrier, _Accumulate, _LiveAccumulator, _AccumulatePair
from fp.callables.protocols import UnaryContract, BinaryContract, ThunkContract, OnceUnary, Unary, MutableUnary, MutableBinary
from fp.callables.invoke import RepeatableUnary, RepeatableBinary, _OnceUnaryAvailable, _OnceBinaryAvailable, _OnceThunkAvailable
from fp.callables._receiver import _unary_repeated_as, _binary_repeated_as, _unary_once_as, _thunk_once_as
from fp.callables._binding import _BindFirst
from fp._internal.errors import _ErrorCompatible
from fp.effects._io_core import IOContext
from fp.effects.outcomes import EffectFailure
from .kernel import Machine as _Machine, Step
from .composition import Pure as _Pure, Bind, Loop, _LoopPolicy, pure as _pure

from .composition import _Selected
from fp.callables._identity import Identity
from fp.data import Left, Right
from fp.iteration._advance import _Source, _source, _next_optional
from std.iter import Iterator, IterableOwned
from std.utils import Variant


trait Machine(_Machine, _FamilyCarrier):
    """A concretely typed cooperative leaf with native family metadata.

    Declare Value and Error, Family = Async[Error], and a mutating poll accepting
    IOContext[Error] and returning Step[Value, Error]. Poll must return promptly;
    terminal steps discharge entered external work and cleanup. Driver and the
    library's combinators own polling. Implementations retain independent
    external origins, never a temporary per-poll context loan.
    """
    # Extension carriers declare Family = Async[E] explicitly. The pinned
    # compiler cannot reliably resolve this associated type as a trait default.
    pass


@fieldwise_init
struct _Recipe[P: _Machine](Machine):
    var _program: Self.P
    comptime Family = Async[Self.P.Error]
    comptime Value = Self.P.Value
    comptime Error = Self.P.Error
    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        return self._program.poll(rebind[IOContext[type_of(self._program).Error]](context))


@fieldwise_init
struct _Map[F: UnaryContract & Movable & Deinitable, E: Movable & Deinitable](OnceUnary):
    var function: Self.F
    comptime Arg = Self.F.Arg
    comptime Out = _Pure[Self.F.Out, Self.E]
    comptime Error = Self.F.Error
    def call_once(deinit self, var value: Self.Arg) raises Self.Error -> Self.Out:
        return _pure[Self.E](_unary_once_as[Self.Error](self.function^, value^))


@fieldwise_init
struct _Combine[F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable, E: Movable & Deinitable](OnceUnary):
    var function: Self.F
    var right: Self.R
    comptime Arg = Self.F.First
    comptime Next = downcast[Self.R.Out, _Machine]
    comptime Out = Bind[Self.Next, _Map[_BindFirst[Self.F], Self.E]]
    comptime Error = Self.R.Error
    def call_once(deinit self, var value: Self.Arg) raises Self.Error -> Self.Out:
        return Self.Out(rebind_var[Self.Next](_thunk_once_as[Self.Error](self.right^)), _Map[_BindFirst[Self.F], Self.E](_BindFirst(self.function^, value^)))


@fieldwise_init
struct _FoldFactory[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator, E: Movable & Deinitable](MutableUnary):
    var source: _Source[Self.V]
    var prepare: Self.P
    var function: Self.F
    var ended: Bool
    comptime Arg = Self.K.Acc
    comptime Done = _Pure[Self.Arg, Self.E]
    comptime Next = downcast[Self.F.Out, _Machine]
    comptime Out = _Selected[Self.Done, Self.Next]
    comptime Error = Self.E
    def call_mut(mut self, var acc: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.P] and RepeatableBinary[Self.F]
        comptime assert Self.P.Arg == _Source[Self.V].Element and Self.P.Out == Self.F.Second
        comptime assert Self.F.First == Self.Arg and Self.Next.Value == Self.Arg
        comptime assert _ErrorCompatible[Self.E, Self.P.Error] and _ErrorCompatible[Self.E, Self.F.Error]
        comptime Branch = Variant[Left[Self.Done], Right[Self.Next]]
        if not Self.K.live(acc):
            self.ended = True
            return Self.Out(Branch(Left(_pure[Self.E](acc^))))
        var item = _next_optional[Self.P.Arg](self.source)
        if not item:
            self.ended = True
            return Self.Out(Branch(Left(_pure[Self.E](acc^))))
        var prepared = _unary_repeated_as[Self.E](self.prepare, item.take())
        var next = _binary_repeated_as[Self.E](self.function, rebind_var[Self.F.First](acc^), rebind_var[Self.F.Second](prepared^))
        return Self.Out(Branch(Right(rebind_var[Self.Next](next^))))


struct _FoldControl[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator, E: Movable & Deinitable](_LoopPolicy):
    comptime Factory = _FoldFactory[Self.V, Self.P, Self.F, Self.K, Self.E]
    comptime Item = Self.K.Acc
    comptime Value = Self.K.Acc
    @staticmethod
    def done(factory: Self.Factory, item: Self.Item) -> Bool:
        return factory.ended or not Self.K.live(item)
    @staticmethod
    def result(var item: Self.Item) -> Self.Value:
        return item^
    @staticmethod
    def next(var item: Self.Item) -> Self.Factory.Arg:
        return item^


def _make_fold[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator, E: Movable & Deinitable](var source: V, var prepare: P, var function: F, var initial: K.Acc) -> Loop[_FoldFactory[V, P, F, K, E], _FoldControl[V, P, F, K, E]]:
    return Loop[_FoldFactory[V, P, F, K, E], _FoldControl[V, P, F, K, E]](initial^, _FoldFactory[V, P, F, K, E](_source(source^), prepare^, function^, False))


@fieldwise_init
struct _StartFold[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator, E: Movable & Deinitable](OnceUnary):
    var source: Self.V
    var prepare: Self.P
    var function: Self.F
    var initial: Self.K.Acc
    comptime Arg = NoneType
    comptime Out = Loop[_FoldFactory[Self.V, Self.P, Self.F, Self.K, Self.E], _FoldControl[Self.V, Self.P, Self.F, Self.K, Self.E]]
    def call_once(deinit self, var unit: NoneType) -> Self.Out:
        return _make_fold[Self.V, Self.P, Self.F, Self.K, Self.E](self.source^, self.prepare^, self.function^, self.initial^)


@fieldwise_init
struct _CollectStep[F: UnaryContract & Movable & Deinitable, K: _Accumulate, E: Movable & Deinitable](MutableBinary):
    var function: Self.F
    comptime First = Self.K.Acc
    comptime Second = Self.F.Arg
    comptime Out = Bind[downcast[Self.F.Out, _Machine], _Map[_BindFirst[_AccumulatePair[Self.K]], Self.E]]
    comptime Error = Self.F.Error
    def call_mut(mut self, var acc: Self.First, var item: Self.Second) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F]
        var next = _unary_repeated_as[Self.Error](self.function, item^)
        return Self.Out(rebind_var[downcast[Self.F.Out, _Machine]](next^), _Map[_BindFirst[_AccumulatePair[Self.K]], Self.E](_BindFirst(_AccumulatePair[Self.K](), acc^)))


@fieldwise_init
struct _StartCollect[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate, E: Movable & Deinitable](OnceUnary):
    var source: Self.V
    var function: Self.F
    comptime Arg = NoneType
    comptime Out = Loop[_FoldFactory[Self.V, Identity[Self.F.Arg], _CollectStep[Self.F, Self.K, Self.E], Self.K, Self.E], _FoldControl[Self.V, Identity[Self.F.Arg], _CollectStep[Self.F, Self.K, Self.E], Self.K, Self.E]]
    comptime Error = Self.K.Error
    def call_once(deinit self, var unit: NoneType) raises Self.Error -> Self.Out:
        return _make_fold[Self.V, Identity[Self.F.Arg], _CollectStep[Self.F, Self.K, Self.E], Self.K, Self.E](self.source^, Identity[Self.F.Arg](), _CollectStep[Self.F, Self.K, Self.E](self.function^), Self.K.start())


@fieldwise_init
struct _Mapped[P: _Machine, F: UnaryContract & Movable & Deinitable, E: Movable & Deinitable](Machine):
    comptime Family = Async[Self.E]
    comptime Value = Self.F.Out
    comptime Error = Self.E
    var _program: Bind[Self.P, _Map[Self.F, Self.E]]
    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        comptime assert type_of(self._program).Error == Self.Error and type_of(self._program).Value == Self.Value
        return rebind_var[Step[Self.Value, Self.Error]](self._program.poll(rebind[IOContext[type_of(self._program).Error]](context)))


@fieldwise_init
struct _Bound[P: _Machine, F: UnaryContract & Movable & Deinitable, E: Movable & Deinitable](Machine):
    comptime Family = Async[Self.E]
    comptime Value = downcast[Self.F.Out, _Machine].Value
    comptime Error = Self.E
    var _program: Bind[Self.P, Self.F]
    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        comptime assert type_of(self._program).Error == Self.Error and type_of(self._program).Value == Self.Value
        return rebind_var[Step[Self.Value, Self.Error]](self._program.poll(rebind[IOContext[type_of(self._program).Error]](context)))


@fieldwise_init
struct _Combined[P: _Machine, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable, E: Movable & Deinitable](Machine):
    comptime Family = Async[Self.E]
    comptime Value = Self.F.Out
    comptime Error = Self.E
    var _program: Bind[Self.P, _Combine[Self.F, Self.R, Self.E]]
    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        comptime assert type_of(self._program).Error == Self.Error and type_of(self._program).Value == Self.Value
        return rebind_var[Step[Self.Value, Self.Error]](self._program.poll(rebind[IOContext[type_of(self._program).Error]](context)))


@fieldwise_init
struct _Folded[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator, E: Movable & Deinitable](Machine):
    comptime Family = Async[Self.E]
    comptime Value = Self.K.Acc
    comptime Error = Self.E
    var _program: Bind[_Pure[NoneType, Self.E], _StartFold[Self.V, Self.P, Self.F, Self.K, Self.E]]
    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        comptime assert type_of(self._program).Error == Self.Error and type_of(self._program).Value == Self.Value
        return rebind_var[Step[Self.Value, Self.Error]](self._program.poll(rebind[IOContext[type_of(self._program).Error]](context)))


@fieldwise_init
struct _Collected[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate, E: Movable & Deinitable](Machine):
    comptime Family = Async[Self.E]
    comptime Value = Self.K.Acc
    comptime Error = Self.E
    var _program: Bind[_Pure[NoneType, Self.E], _StartCollect[Self.V, Self.F, Self.K, Self.E]]
    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        comptime assert type_of(self._program).Error == Self.Error and type_of(self._program).Value == Self.Value
        return rebind_var[Step[Self.Value, Self.Error]](self._program.poll(rebind[IOContext[type_of(self._program).Error]](context)))


@fieldwise_init
struct _Handled[P: _Machine, H: UnaryContract & Movable & Deinitable, E: Movable & Deinitable](Machine):
    comptime Family = Async[Self.E]
    comptime Value = Self.P.Value
    comptime Error = Self.E
    var _program: Bind[Self.P, Self.H, True]
    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        comptime assert type_of(self._program).Error == Self.Error and type_of(self._program).Value == Self.Value
        return rebind_var[Step[Self.Value, Self.Error]](self._program.poll(rebind[IOContext[Self.P.Error]](context)))


struct Async[E: Movable & Deinitable](Monad, ErrorRecovery):
    """The native sequencing and recovery family for cooperative async recipes.

    Construction owns unopened work; execution captures compatible callback
    errors in the canonical outcome. Dependent composition stays sequential.
    Use explicit both for child concurrency. This dictionary does not claim the
    complete Cats Effect Async capability set or erase concrete recipe types.

    Parameters:
        E: The exact domain error shared by every recipe in this family.
    """
    comptime Element[V: Movable & Deinitable] = downcast[V, _Machine].Value
    comptime CarrierCompatible[V: Movable & Deinitable] = (downcast[V, _Machine].Error == Self.E) if conforms_to(V, _Machine) else False
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.CarrierCompatible[V] and _OnceUnaryAvailable[F] and _ErrorCompatible[Self.E, F.Error]
    comptime BindCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.CarrierCompatible[V] and Self.CarrierCompatible[F.Out] and _OnceUnaryAvailable[F] and _ErrorCompatible[Self.E, F.Error]
    comptime CombineCompatible[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Self.CarrierCompatible[V] and Self.CarrierCompatible[R.Out] and _OnceBinaryAvailable[F] and _OnceThunkAvailable[R] and _ErrorCompatible[Self.E, F.Error] and _ErrorCompatible[Self.E, R.Error]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _Mapped[downcast[V, _Machine], F, Self.E]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Never
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _Bound[downcast[V, _Machine], F, Self.E]
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Never
    comptime Pure[A: Movable & Deinitable] = _Recipe[_Pure[A, Self.E]]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = _Combined[downcast[V, _Machine], F, R, Self.E]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Never

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        """Own an already evaluated value in an unopened recipe.

        Parameters:
            A: The exact owned value type, retaining native origins.

        Args:
            value: The value, consumed once.

        Returns:
            A concrete recipe in this family.
        """
        return Self.Pure[A](_pure[Self.E](value^))

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) -> Self.Mapped[V, F]:
        """Defer one callback after a successful source outcome.

        Parameters:
            V: The source carrier admitted by this family.
            F: A once-admitted callback with a compatible native error.

        Args:
            f: The owned callback, receiving the success value.
            value: The unopened source, consumed once.

        Returns:
            A recipe capturing callback failure during execution. Error and
            cancellation outcomes bypass the callback.
        """
        comptime assert Self.MapCompatible[V, F]
        return Self.Mapped[V, F](Bind(rebind_var[downcast[V, _Machine]](value^), _Map[F, Self.E](f^)))

    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) -> Self.Bound[V, F]:
        """Sequence a dependent recipe through the canonical bind owner.

        Parameters:
            V: The source carrier admitted by this family.
            F: A once-admitted continuation returning the same exact error family.

        Args:
            f: The owned continuation, deferred until success and an entry checkpoint.
            value: The unopened source, consumed once.

        Returns:
            A concrete recipe owning both execution lifetimes in sequence.
        """
        comptime assert Self.BindCompatible[V, F]
        return Self.Bound[V, F](Bind(rebind_var[downcast[V, _Machine]](value^), f^))

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var f: F, var left: V, var right: R) -> Self.Combined[V, F, R]:
        """Run the left recipe, build and run the right, then combine their values.

        Parameters:
            V: The left carrier admitted by this family.
            F: The once-admitted combiner of the exact left and right values.
            R: The once-admitted factory returning a recipe in this error family.

        Args:
            f: The owned combining callback.
            left: The owned left recipe.
            right: The owned right factory, deferred until left succeeds.

        Returns:
            Sequential dependent composition; use both for concurrent children.
        """
        comptime assert Self.CombineCompatible[V, F, R]
        return Self.Combined[V, F, R](Bind(rebind_var[downcast[V, _Machine]](left^), _Combine[F, R, Self.E](f^, right^)))

    comptime _JoinCompatible[L: Movable & Deinitable, R: Movable & Deinitable] = Self.CarrierCompatible[L] and Self.CarrierCompatible[R] and Self.Element[L] == Self.Element[R]
    comptime _Joined[L: Movable & Deinitable, R: Movable & Deinitable] = _Recipe[_Selected[downcast[L, _Machine], downcast[R, _Machine]]]
    @staticmethod
    def _join_left[L: Movable & Deinitable, R: Movable & Deinitable](var value: L) -> Self._Joined[L, R]:
        comptime assert Self._JoinCompatible[L, R]
        return Self._Joined[L, R](_Selected[downcast[L, _Machine], downcast[R, _Machine]](Variant[Left[downcast[L, _Machine]], Right[downcast[R, _Machine]]](Left(rebind_var[downcast[L, _Machine]](value^)))))
    @staticmethod
    def _join_right[L: Movable & Deinitable, R: Movable & Deinitable](var value: R) -> Self._Joined[L, R]:
        comptime assert Self._JoinCompatible[L, R]
        return Self._Joined[L, R](_Selected[downcast[L, _Machine], downcast[R, _Machine]](Variant[Left[downcast[L, _Machine]], Right[downcast[R, _Machine]]](Right(rebind_var[downcast[R, _Machine]](value^)))))

    comptime _FoldCompatible[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator] = (RepeatableUnary[P] and RepeatableBinary[F] and P.Arg == _Source[V].Element and P.Out == F.Second and F.First == K.Acc and Self.CarrierCompatible[F.Out] and Self.Element[F.Out] == K.Acc and _ErrorCompatible[Self.E, P.Error] and _ErrorCompatible[Self.E, F.Error]) if conforms_to(V, Iterator) or conforms_to(V, IterableOwned) else False
    comptime _Folded[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator] = _Folded[V, P, F, K, Self.E]
    comptime _FoldError[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator] = Never
    @staticmethod
    def _fold[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator](var prepare: P, var step: F, var initial: K.Acc, var source: V) -> Self._Folded[V, P, F, K]:
        comptime assert Self._FoldCompatible[V, P, F, K]
        var unit: NoneType = None
        return Self._Folded[V, P, F, K](Bind(_pure[Self.E](unit), _StartFold[V, P, F, K, Self.E](source^, prepare^, step^, initial^)))

    comptime CollectCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.CarrierCompatible[F.Out] and RepeatableUnary[F] and _ErrorCompatible[Self.E, F.Error]
    comptime _LoopCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = (Self.CollectCompatible[V, F] and Self.Element[F.Out] == K.Item and _Source[V].Element == F.Arg and _ErrorCompatible[Self.E, K.Error]) if conforms_to(V, Iterator) or conforms_to(V, IterableOwned) else False
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = _Collected[V, F, K, Self.E]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Never
    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V) -> Self._Looped[V, F, K]:
        comptime assert Self._LoopCompatible[V, F, K]
        var unit: NoneType = None
        return Self._Looped[V, F, K](Bind(_pure[Self.E](unit), _StartCollect[V, F, K, Self.E](source^, f^)))

    comptime Failure = EffectFailure[Self.E]
    comptime _ErrorCarrier[V: Movable & Deinitable] = Self.CarrierCompatible[V]
    comptime _Handles[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = (Self.Element[V] == Self.Element[H.Out] and H.Arg == Self.Failure and _OnceUnaryAvailable[H] and _ErrorCompatible[Self.E, H.Error]) if Self.CarrierCompatible[V] and Self.CarrierCompatible[H.Out] else False
    comptime Handled[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = _Handled[downcast[V, _Machine], H, Self.E]
    comptime HandleError[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = Never
    @staticmethod
    def or_else[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V) -> Self.Handled[V, H]:
        """Recover an ordinary failure through the canonical bind continuation.

        Parameters:
            V: The source carrier in this family.
            H: A once-admitted handler of EffectFailure[E], preserving value and error types.

        Args:
            handler: The owned recovery callback; cancellation bypasses it.
            source: The unopened source, consumed once.

        Returns:
            A recipe retaining full ordered errors and the cancellation flag.
        """
        comptime assert Self._Handles[V, H]
        return Self.Handled[V, H](Bind[downcast[V, _Machine], H, True](rebind_var[downcast[V, _Machine]](source^), handler^))
