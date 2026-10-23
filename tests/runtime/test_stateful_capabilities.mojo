"""State laws, explicit layer selection and unchanged transformer semantics."""
from fp.algebra import StringMonoid, ResultFamily, flat_map, fail, pure
from fp.effects import Stateful, LiftStateful, State, StateT, ReaderT, WriterT, OptionalT, ResultT, get, put, modify, run, run_writer, tell
from fp.callables import Unary
from std.testing import assert_equal


@fieldwise_init
struct SCAdd(Unary, Copyable):
    var amount: Int
    comptime Arg = Int
    comptime Out = Int
    def call(self, var value: Int) -> Int: return value + self.amount


def sc_read[C: Stateful]() raises C.GetError -> C.Got where C.GetAvailable:
    return get[C]()


def sc_bump[C: Stateful](amount: Int) raises C.ModifyError[SCAdd] -> C.Modified[SCAdd] where C.StateType == Int and C.ModifyCompatible[SCAdd]:
    return modify[C](SCAdd(amount))


def main() raises:
    comptime S = State[Int]
    var unchanged = run[S](sc_read[S](), 10)
    assert_equal(unchanged[0], 10)
    assert_equal(unchanged[1], 10)
    def read_after(var unused: NoneType) -> S.Got: return sc_read[S]()
    var written = run[S](flat_map[S](read_after, put[S](20)), 10)
    assert_equal(written[0], 20)
    assert_equal(written[1], 20)
    def write_read(var value: Int) -> type_of(put[S](value)): return put[S](value)
    assert_equal(run[S](flat_map[S](write_read, get[S]()), 10)[1], 10)
    def write_again(var unused: NoneType) -> type_of(put[S](30)): return put[S](30)
    assert_equal(run[S](flat_map[S](write_again, put[S](20)), 10)[1], 30)
    assert_equal(run[S](sc_bump[S](0), 10)[1], 10)
    def plus_three(var unused: NoneType) -> S.Modified[SCAdd]: return sc_bump[S](3)
    assert_equal(run[S](flat_map[S](plus_three, sc_bump[S](2)), 10)[1], run[S](sc_bump[S](5), 10)[1])
    var replay = sc_bump[S](3)
    var copy = replay.copy()
    assert_equal(run[S](copy^, 10)[1], 13)
    assert_equal(run[S](replay^, 20)[1], 23)

    comptime R = ReaderT[S, String]
    comptime RC = LiftStateful[R, S]
    var reader_base = run[R](sc_bump[RC](3), String("unchanged"))
    assert_equal(run[S](reader_base^, 10)[1], 13)
    var reader_read = run[R](sc_read[RC](), String("unused"))
    assert_equal(run[S](reader_read^, 10)[0], 10)

    comptime W = WriterT[S, StringMonoid]
    comptime WC = LiftStateful[W, S]
    var logged = run[S](run_writer[W](sc_bump[WC](3)), 10)
    assert_equal(logged[0][0], "")
    assert_equal(logged[1], 13)
    def after_log(var unused: NoneType) -> WC.Modified[SCAdd]: return sc_bump[WC](3)
    var with_log = run[S](run_writer[W](flat_map[W](after_log, tell[W](String("kept")))), 10)
    assert_equal(with_log[0][0], "kept")
    assert_equal(with_log[1], 13)
    var writer_read = run[S](run_writer[W](sc_read[WC]()), 10)
    assert_equal(writer_read[0][1], 10)

    comptime O = OptionalT[S]
    comptime OC = LiftStateful[O, S]
    var optional = run[S](sc_bump[OC](3), 10)
    assert_equal(Bool(optional[0]), True)
    assert_equal(optional[1], 13)
    var optional_read = run[S](sc_read[OC](), 10)
    assert_equal(optional_read[0].value(), 10)
    def after_absent(var unused: NoneType) -> OC.Modified[SCAdd]: return sc_bump[OC](3)
    var absent = run[S](flat_map[O](after_absent, pure[S](Optional[NoneType]())), 10)
    assert_equal(Bool(absent[0]), False)
    assert_equal(absent[1], 10)

    comptime T = ResultT[S, String]
    comptime TC = LiftStateful[T, S]
    var result = run[S](sc_bump[TC](3), 10)
    assert_equal(result[0].is_ok(), True)
    assert_equal(result[1], 13)
    var result_read = run[S](sc_read[TC](), 10)
    assert_equal(result_read[0]._ok().value, 10)
    def reject_after(var unused: NoneType) -> type_of(fail[T, Int](String("stored"))):
        return fail[T, Int](String("stored"))
    var kept = run[S](flat_map[T](reject_after, sc_bump[TC](3)), 10)
    assert_equal(kept[0]._err().value, "stored")
    assert_equal(kept[1], 13)
    def skip_update(var unused: NoneType) -> TC.Modified[SCAdd]: return sc_bump[TC](3)
    var skipped = run[S](flat_map[T](skip_update, fail[T, NoneType](String("skip"))), 10)
    assert_equal(skipped[0]._err().value, "skip")
    assert_equal(skipped[1], 10)
    comptime D = StateT[ResultFamily[String], Int]
    def discard_after(var unused: NoneType) -> type_of(fail[D, Int](String("stored"))):
        return fail[D, Int](String("stored"))
    var discarded = run[D](flat_map[D](discard_after, sc_bump[D](3)), 10)
    assert_equal(discarded._err().value, "stored")

    # Identical types do not make state selection ambiguous.
    comptime Two = StateT[S, Int]
    comptime Inner = LiftStateful[Two, S]
    var inner = run[S](run[Two](sc_bump[Inner](3), 100), 10)
    assert_equal(inner[0][1], 100)
    assert_equal(inner[1], 13)
    var outer = run[S](run[Two](sc_bump[Two](3), 100), 10)
    assert_equal(outer[0][1], 103)
    assert_equal(outer[1], 10)
    var inner_read = run[S](run[Two](sc_read[Inner](), 100), 10)
    assert_equal(inner_read[0][0], 10)
    var outer_read = run[S](run[Two](sc_read[Two](), 100), 10)
    assert_equal(outer_read[0][0], 100)

    comptime Nested = ResultT[R, String]
    comptime NC = LiftStateful[Nested, RC]
    var nested = run[S](run[R](sc_bump[NC](3), String("unused")), 10)
    assert_equal(nested[0].is_ok(), True)
    assert_equal(nested[1], 13)
    var replaced = run[S](run[R](put[NC](77), String("unused")), 10)
    assert_equal(replaced[1], 77)
    var amount = 4
    def native_update(var state: Int) {amount} -> Int: return state + amount
    var native_result = run[S](run[R](modify[NC](native_update), String("unused")), 10)
    assert_equal(native_result[1], 14)

    def native_failure(var state: Int) raises Int -> Int: raise state + 70
    var pending = modify[TC](native_failure)
    var code = 0
    try: _ = run[S](pending^, 10)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 80)
    print("Stateful capabilities: laws, explicit selection, stack order and native errors")
