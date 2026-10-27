"""Branch selection shared by single-value traversal and transformers."""

from std.builtin.rebind import rebind_var, downcast
from fp.algebra.protocols import _pure, Applicative, _UnaryView
from fp.callables.protocols import UnaryContract, OnceUnary, MutableUnary
from fp.callables.invoke import call_once, RepeatableUnary
from fp.callables._receiver import _unary_once_as
from fp.data._result import Result, _ResultType, _fold_result_owned, _transformed
from fp.iteration._advance import _OwnedElement
from fp._internal.errors import _CommonError, _ErrorCompatible
from ._adapt import _map_as


@fieldwise_init
struct _OptionalGuard[M: Applicative, F: UnaryContract & Movable & Deinitable](
    OnceUnary, MutableUnary where RepeatableUnary[F], Copyable where conforms_to(F, Copyable)
):
    """Select an Optional branch inside an applicative target. Absence returns
    pure absence; presence calls F, whose result is the selected computation."""
    var function: Self.F
    comptime B = _OwnedElement[Self.M.Element[Self.F.Out]]
    comptime Absent = Self.M.Pure[Optional[Self.B]]
    comptime Arg = Optional[Self.F.Arg]
    comptime Out = Self.M._Joined[Self.Absent, Self.F.Out]
    comptime Error = Self.F.Error
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        if not arg:
            return Self.M._join_left[Self.Absent, Self.F.Out](_pure[Self.M](Optional[Self.B]()))
        return Self.M._join_right[Self.Absent, Self.F.Out](call_once(self.function^, arg.unsafe_take()))
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F]
        comptime View = _UnaryView[Self.F, origin_of(self.function)]
        comptime Guard = _OptionalGuard[Self.M, View]
        comptime assert Guard.Arg == Self.Arg and Guard.Out == Self.Out
        return rebind_var[Self.Out](Guard(View(Pointer(to=self.function))).call_once(rebind_var[Guard.Arg](arg^)))


@fieldwise_init
struct _ResultGuard[M: Applicative, E: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, success: Bool = True](
    OnceUnary, MutableUnary where RepeatableUnary[F], Copyable where conforms_to(F, Copyable)
):
    """Continue or recover one Result branch through its consuming fold.

    The unselected branch is lifted through pure; the selected branch returns
    the callback's base effect. Base joins retain concrete deferred actions.
    """
    var function: Self.F
    comptime B = downcast[Self.M.Element[Self.F.Out], _ResultType].Value
    comptime A = Self.F.Arg if Self.success else Self.B
    comptime Absent = Self.M.Pure[Result[Self.B, Self.E]]
    comptime Arg = Result[Self.A, Self.E]
    comptime Out = Self.M._Joined[Self.Absent, Self.F.Out]
    comptime Error = Self.F.Error

    @staticmethod
    def _preserve[P: Movable & Deinitable](var payload: P, var unused: NoneType) capturing -> Self.Out:
        return Self.M._join_left[Self.Absent, Self.F.Out](_pure[Self.M](
            _transformed[Self.B, Self.E, P, not Self.success, True](payload^)))

    @staticmethod
    def _continue[P: Movable & Deinitable](var payload: P, var function: Self.F) raises Self.Error capturing -> Self.Out:
        comptime assert P == Self.F.Arg
        return Self.M._join_right[Self.Absent, Self.F.Out](call_once(function^, rebind_var[Self.F.Arg](payload^)))

    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime if Self.success:
            return _fold_result_owned[Self.A, Self.E, Self.Out, Self.Error, Self.Error, Never,
                Self.F, NoneType, Self._continue[Self.A], Self._preserve[Self.E]](arg^, self.function^, None)
        else:
            comptime assert Self.F.Arg == Self.E, "or_else: handler must consume the selected stored error"
            return _fold_result_owned[Self.A, Self.E, Self.Out, Self.Error, Never, Self.Error,
                NoneType, Self.F, Self._preserve[Self.A], Self._continue[Self.E]](arg^, None, self.function^)

    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F]
        comptime View = _UnaryView[Self.F, origin_of(self.function)]
        comptime Guard = _ResultGuard[Self.M, Self.E, View, Self.success]
        comptime assert Guard.Arg == Self.Arg and Guard.Out == Self.Out
        return rebind_var[Self.Out](Guard(View(Pointer(to=self.function))).call_once(rebind_var[Guard.Arg](arg^)))


@fieldwise_init
struct _TraverseBranch[G: Applicative, F: UnaryContract & Movable & Deinitable,
                       W: UnaryContract & Movable & Deinitable](OnceUnary):
    """Produce one target carrier and map its source-shape wrapper."""
    var function: Self.F
    var wrap: Self.W
    comptime Arg = Self.F.Arg
    comptime Out = Self.G.Mapped[Self.F.Out, Self.W]
    comptime Error = _CommonError[Self.F.Error, Self.G.MapError[Self.F.Out, Self.W]]
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert _ErrorCompatible[Self.Error, Self.F.Error]
        comptime assert _ErrorCompatible[Self.Error, Self.G.MapError[Self.F.Out, Self.W]]
        var produced = _unary_once_as[Self.Error](self.function^, arg^)
        return _map_as[Self.Error, Self.G](self.wrap^, produced^)
