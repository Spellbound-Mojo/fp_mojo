"""Stored pointers preserve all four read/result ABIs and exact native errors."""
from fp.effects import IO, IOContext, EffectFailure, Outcome, ReaderAction, lift_resource, pure_resource, run_io
from fp.algebra import pure
from fp.data import Result, Ok
from std.testing import assert_equal


@fieldwise_init
struct RegisterIO(ReaderAction, TrivialRegisterPassable):
    var value: Int
    comptime Family = IO[Int]
    comptime Env = IOContext[Int]
    comptime Value = Int
    comptime Out[o: ImmOrigin] = Outcome[Int,Int]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        return Optional(Result[Int,EffectFailure[Int]](Ok(self.value)))


def rr(value: Int) -> RegisterIO: return RegisterIO(value)
def rr_other(value: Int) -> RegisterIO: return RegisterIO(value * 10)
def mr(value: String) -> RegisterIO: return RegisterIO(value.byte_length())
def rm(value: Int) -> IO[Int].Pure[Int]: return pure[IO[Int]](value)
def mm(value: String) -> IO[Int].Pure[Int]: return pure[IO[Int]](value.byte_length())
def never(value: Int) raises Never -> RegisterIO: return RegisterIO(value)
def never_memory(value: String) raises Never -> IO[Int].Pure[Int]:
    return pure[IO[Int]](value.byte_length())
def raising(value: Int) raises Int -> RegisterIO:
    if value < 0: raise 71
    return RegisterIO(value)


def checked(var outcome: Outcome[Int,Int], expected: Int) raises:
    var result = outcome.take()
    assert_equal(result._ok().value,expected)


def failed[V: Movable & Deinitable](var outcome: Outcome[V,Int]) raises:
    var result = outcome.take()
    var error = result^._take_err()
    assert_equal(error^.into_errors().into_list(),List[Int]([71]))


def main() raises:
    comptime assert conforms_to(RegisterIO,TrivialRegisterPassable)
    comptime assert not conforms_to(IO[Int].Pure[Int],RegisterPassable)
    var rr_pointer: def(Int) thin -> RegisterIO = rr
    var mr_pointer: def(String) thin -> RegisterIO = mr
    var rm_pointer: def(Int) thin -> IO[Int].Pure[Int] = rm
    var mm_pointer: def(String) thin -> IO[Int].Pure[Int] = mm
    checked(run_io(lift_resource(pure_resource[Int](7)).use(rr_pointer)),7)
    checked(run_io(lift_resource(pure_resource[Int](String("word"))).use(mr_pointer)),4)
    checked(run_io(lift_resource(pure_resource[Int](8)).use(rm_pointer)),8)
    checked(run_io(lift_resource(pure_resource[Int](String("words"))).use(mm_pointer)),5)
    checked(run_io(lift_resource(pure_resource[Int](7)).eval_map(rr_pointer).use(rm)),7)
    checked(run_io(lift_resource(pure_resource[Int](String("word"))).eval_map(mr_pointer).use(rm)),4)
    checked(run_io(lift_resource(pure_resource[Int](8)).eval_map(rm_pointer).use(rm)),8)
    checked(run_io(lift_resource(pure_resource[Int](String("words"))).eval_map(mm_pointer).use(rm)),5)
    checked(run_io(lift_resource(pure_resource[Int](7)).eval_tap(rr_pointer).use(rm)),7)
    checked(run_io(lift_resource(pure_resource[Int](String("word"))).eval_tap(mr_pointer).use(mm)),4)
    checked(run_io(lift_resource(pure_resource[Int](8)).eval_tap(rm_pointer).use(rm)),8)
    checked(run_io(lift_resource(pure_resource[Int](String("words"))).eval_tap(mm_pointer).use(mm)),5)
    var pending = lift_resource(pure_resource[Int](9)).use(rr_pointer)
    rr_pointer = rr_other
    checked(run_io(pending^),9)
    checked(run_io(lift_resource(pure_resource[Int](9)).use(rr_pointer)),90)
    var never_pointer: def(Int) raises Never thin -> RegisterIO = never
    checked(run_io(lift_resource(pure_resource[Int](11)).use(never_pointer)),11)
    checked(run_io(lift_resource(pure_resource[Int](11)).eval_map(never_pointer).use(rm)),11)
    checked(run_io(lift_resource(pure_resource[Int](11)).eval_tap(never_pointer).use(rm)),11)
    var memory_never: def(String) raises Never thin -> IO[Int].Pure[Int] = never_memory
    checked(run_io(lift_resource(pure_resource[Int](String("word"))).use(memory_never)),4)
    checked(run_io(lift_resource(pure_resource[Int](String("word"))).eval_map(memory_never).use(rm)),4)
    checked(run_io(lift_resource(pure_resource[Int](String("word"))).eval_tap(memory_never).use(mm)),4)
    var raising_pointer: def(Int) raises Int thin -> RegisterIO = raising
    checked(run_io(lift_resource(pure_resource[Int](12)).use(raising_pointer)),12)
    failed(run_io(lift_resource(pure_resource[Int](-1)).use(raising_pointer)))
    failed(run_io(lift_resource(pure_resource[Int](-1)).eval_map(raising_pointer).use_void()))
    failed(run_io(lift_resource(pure_resource[Int](-1)).eval_tap(raising_pointer).use_void()))
