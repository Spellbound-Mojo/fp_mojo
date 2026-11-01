"""Third-party dictionaries, checked generic forwarding and distinct error phases."""
from fp.effects import Stateful, LiftStateful, State, ReaderT, WriterT, get, modify, put, run, run_writer
from fp.algebra import IdentityFamily, Monoid
from fp.callables import UnaryContract, Unary, call_once
from std.testing import assert_equal
from std.builtin.rebind import rebind_var


@fieldwise_init
struct SCBuildError(Movable):
    var code: Int


struct SCCheckedState[reject: Bool](Stateful):
    # An external dictionary can reuse a family's state operations without
    # implementing that family's representation or any additional Monad.
    comptime Family = State[Int]
    comptime StateType = Int
    comptime GetAvailable = True
    comptime Got = Self.Family.Got
    comptime GetError = SCBuildError
    comptime ModifyCompatible[F: UnaryContract & Movable & Deinitable] = Self.Family.ModifyCompatible[F]
    comptime Modified[F: UnaryContract & Movable & Deinitable] = Self.Family.Modified[F]
    comptime ModifyError[F: UnaryContract & Movable & Deinitable] = SCBuildError
    @staticmethod
    def get() raises SCBuildError -> Self.Got:
        if Self.reject: raise SCBuildError(11)
        return Self.Family.get()
    @staticmethod
    def modify[F: UnaryContract & Movable & Deinitable](var f: F) raises SCBuildError -> Self.Modified[F]:
        if Self.reject: raise SCBuildError(12)
        return Self.Family.modify(f^)


struct SCUnitState[reject: Bool](Stateful):
    # A lawful eager state: NoneType has one possible value. This exercises
    # capability construction and lift errors in the same phase.
    comptime Family = IdentityFamily
    comptime StateType = NoneType
    comptime GetAvailable = True
    comptime Got = NoneType
    comptime GetError = Int
    comptime ModifyCompatible[F: UnaryContract & Movable & Deinitable] = F.Arg == NoneType and F.Out == NoneType
    comptime Modified[F: UnaryContract & Movable & Deinitable] = F.Out
    comptime ModifyError[F: UnaryContract & Movable & Deinitable] = F.Error
    @staticmethod
    def get() raises Int -> NoneType:
        if Self.reject: raise 11
        return None
    @staticmethod
    def modify[F: UnaryContract & Movable & Deinitable](var f: F) raises F.Error -> F.Out:
        comptime assert F.Arg == NoneType and F.Out == NoneType
        var nothing: NoneType = None
        return call_once(f^, rebind_var[F.Arg](nothing))


struct SCFailingLog(Monoid):
    comptime Value = String
    comptime Error = Int
    @staticmethod
    def empty() raises Int -> String: raise 22
    @staticmethod
    def combine(var left: String, var right: String) raises Int -> String: return left + right


@fieldwise_init
struct SCGenericAdd(Unary, Copyable):
    var amount: Int
    comptime Arg = Int
    comptime Out = Int
    def call(self, var state: Int) -> Int: return state + self.amount


def sc_generic_get[C: Stateful]() raises C.GetError -> C.Got where C.GetAvailable:
    return get[C]()


def sc_generic_modify[C: Stateful, F: UnaryContract & Movable & Deinitable](var f: F
) raises C.ModifyError[F] -> C.Modified[F] where C.ModifyCompatible[F] and F.Arg == C.StateType and F.Out == C.StateType:
    return modify[C](f^)


def main() raises:
    comptime S = State[Int]
    comptime R = ReaderT[S, String]
    comptime Bad = LiftStateful[R, SCCheckedState[True]]
    var code = 0
    try: _ = sc_generic_get[Bad]()
    except error:
        comptime assert type_of(error) == SCBuildError
        code = error.code
    assert_equal(code, 11)
    try: _ = sc_generic_modify[Bad](SCGenericAdd(3))
    except error:
        comptime assert type_of(error) == SCBuildError
        code = error.code
    assert_equal(code, 12)
    code = 0
    try: _ = put[Bad](20)
    except error:
        comptime assert type_of(error) == SCBuildError
        code = error.code
    assert_equal(code, 12)

    comptime Good = LiftStateful[R, SCCheckedState[False]]
    var final_state: Int
    try:
        var pending = sc_generic_modify[Good](SCGenericAdd(3))
        final_state = run[S](run[R](pending^, String("unused")), 10)[1]
    except error:
        raise Error("unexpected construction error")
    assert_equal(final_state, 13)
    var read_value: Int
    try:
        var pending = sc_generic_get[Good]()
        read_value = run[S](run[R](pending^, String("unused")), 10)[0]
    except error:
        raise Error("unexpected construction error")
    assert_equal(read_value, 10)

    # Writer's log failure remains a run error, distinct from construction.
    comptime W = WriterT[S, SCFailingLog]
    comptime C = LiftStateful[W, SCCheckedState[False]]
    var pending: C.Modified[SCGenericAdd]
    try: pending = sc_generic_modify[C](SCGenericAdd(3))
    except error:
        raise Error("unexpected construction error")
    var execution_error = 0
    try: _ = run[S](run_writer[W](pending^), 10)
    except error:
        comptime assert type_of(error) == Int
        execution_error = error
    assert_equal(execution_error, 22)
    comptime Eager = WriterT[IdentityFamily, SCFailingLog]
    comptime EC = LiftStateful[Eager, SCUnitState[False]]
    code = 0
    try: _ = get[LiftStateful[Eager, SCUnitState[True]]]()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 11)
    try: _ = get[EC]()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 22)
    def reject_update(var state: NoneType) raises Int -> NoneType: raise 33
    try: _ = modify[EC](reject_update)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 33)
    try: _ = put[EC](None)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 22)
    print("Stateful capabilities: external dictionaries, generic admission, exact error phases")
