"""Explicit environment selection, scope laws, and representation-preserving lifts."""
from fp.algebra import StringMonoid, pure, flat_map, fail
from fp.effects import Ask, Local, LiftAsk, LiftLocal, Reader, ReaderT, StateT, WriterT, OptionalT, ResultT, ask, local, run, run_writer, put, writer
from fp.callables import BorrowCallable, as_unary
from std.testing import assert_equal


@fieldwise_init
struct ECAdd(BorrowCallable, Copyable):
    var amount: Int
    comptime Payload = Int
    comptime Result = Int
    def invoke(self, ref value: Int) raises Never capturing -> Int:
        return value + self.amount


def program[C: Ask]() raises C.AskError -> C.Asked where C.AskAvailable:
    return ask[C]()


def scoped[C: Local, V: Movable & Deinitable](var value: V) raises C.LocalError[V, ECAdd] -> C.Localized[V, ECAdd] where C.Environment == Int and C.LocalCompatible[V]:
    return local[C](ECAdd(2), value^)


def main() raises:
    comptime R = Reader[Int]
    var env = 5
    assert_equal(run[R](scoped[R](program[R]()), env), 7)
    var replay = scoped[R](program[R]())
    var copy = replay.copy()
    assert_equal(run[R](copy^, env), 7)
    assert_equal(run[R](replay^, 9), 11)
    # Identity, composition and restoration laws.
    assert_equal(run[R](local[R](ECAdd(0), ask[R]()), env), 5)
    assert_equal(run[R](local[R](ECAdd(2), local[R](ECAdd(3), ask[R]())), env), 10)
    assert_equal(run[R](local[R](ECAdd(5), ask[R]()), env), 10)
    assert_equal(run[R](ask[R](), env), 5)
    assert_equal(run[R](local[R](ECAdd(20), pure[R](9)), env), 9)
    def again(var value: Int) -> R.Asked: return ask[R]()
    var restored = flat_map[R](as_unary(again), local[R](ECAdd(3), ask[R]()))
    assert_equal(run[R](restored^, env), 5)

    comptime S = StateT[R, Int]
    comptime SC = LiftLocal[S, R]
    var state_base = run[S](scoped[SC](program[SC]()), 42)
    var pair = run[R](state_base^, env)
    assert_equal(pair[0], 7)
    assert_equal(pair[1], 42)
    def after_put(var nothing: NoneType) -> SC.Asked: return ask[SC]()
    var updated = flat_map[S](as_unary(after_put), put[S](99))
    var updated_base = run[S](scoped[SC](updated^), 42)
    var updated_pair = run[R](updated_base^, env)
    assert_equal(updated_pair[0], 7)
    assert_equal(updated_pair[1], 99)

    comptime W = WriterT[R, StringMonoid]
    comptime WC = LiftLocal[W, R]
    var writer_base = run_writer[W](scoped[WC](program[WC]()))
    var logged = run[R](writer_base^, env)
    assert_equal(logged[0], "")
    assert_equal(logged[1], 7)
    var existing = writer[W, Int](pure[R](Tuple(String("kept"), 8)))
    var existing_base = run_writer[W](scoped[WC](existing^))
    var existing_log = run[R](existing_base^, env)
    assert_equal(existing_log[0], "kept")
    assert_equal(existing_log[1], 8)

    comptime O = OptionalT[R]
    comptime OC = LiftLocal[O, R]
    var optional = run[R](scoped[OC](program[OC]()), env)
    assert_equal(optional.take(), 7)
    var absent = run[R](scoped[OC](pure[R](Optional[Int]())), env)
    assert_equal(absent, None)

    comptime T = ResultT[R, String]
    comptime TC = LiftLocal[T, R]
    var result = run[R](scoped[TC](program[TC]()), env)
    assert_equal(result^.raise_on_err(), 7)
    var failed = run[R](scoped[TC](fail[T, Int](String("stored"))), env)
    assert_equal(failed._err().value, "stored")
    def reject(value: Int) raises Int -> Int: raise value + 70
    var raised = local[TC](reject, ask[TC]())
    var native_code = 0
    try:
        _ = run[R](raised^, env)
    except error:
        comptime assert type_of(error) == Int
        native_code = error
    assert_equal(native_code, 75)

    # Two Readers with identical environment types are selected by position.
    comptime RR = ReaderT[R, Int]
    comptime Inner = LiftLocal[RR, R]
    var inner_read = run[RR](scoped[Inner](program[Inner]()), 99)
    assert_equal(run[R](inner_read^, env), 7)
    var outer_read = run[RR](scoped[RR](program[RR]()), 99)
    assert_equal(run[R](outer_read^, env), 101)
    var lifted = run[RR](ask[LiftAsk[RR, R]](), 99)
    assert_equal(run[R](lifted^, env), 5)

    comptime OS = OptionalT[S]
    comptime OSC = LiftLocal[OS, SC]
    var nested = run[S](scoped[OSC](program[OSC]()), 17)
    var nested_pair = run[R](nested^, env)
    assert_equal(nested_pair[0].value(), 7)
    assert_equal(nested_pair[1], 17)
    print("Environment capabilities: laws, generic stacks, explicit selection")
