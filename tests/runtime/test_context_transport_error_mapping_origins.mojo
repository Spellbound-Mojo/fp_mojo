"""Rebinding retains both output origins and the Reader's actual run error origin."""
from fp.algebra import ResultFamily, StringMonoid
from fp.effects import ReaderAction, ReaderT, StateT, WriterT, run, run_writer
from fp.functions import pipeline
from fp.data import Result, Ok
from std.testing import assert_equal

@fieldwise_init
struct EnvRaises(ReaderAction, Defaultable):
    comptime Family = ReaderT[ResultFamily[String],List[Int]]
    comptime Env = List[Int]
    comptime Value = Int
    comptime Out[o: ImmOrigin] = Result[Int,String]
    comptime Error[o: ImmOrigin] = Span[Int,o]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) raises Self.Error[o] -> Self.Out[o]:
        raise Span(env)

def origins(left: List[Int], right: List[Int]) raises:
    comptime Left = type_of(Span(left))
    comptime Right = type_of(Span(right))
    comptime R = ReaderT[ResultFamily[Left],Int]
    comptime R2 = ReaderT[ResultFamily[Right],Int]
    comptime S = StateT[ResultFamily[Left],Left]
    comptime S2 = StateT[ResultFamily[Right],Left]
    comptime W = WriterT[ResultFamily[Left],StringMonoid]
    comptime W2 = WriterT[ResultFamily[Right],StringMonoid]
    def keep(var value: Left) -> Left: return value
    def replace(var error: Left) {ref right} -> Right: return Span(right)
    var success = run[R2](pipeline[R](R.pure(Span(left))).map_both(keep,replace).get(),0)
    comptime assert type_of(success) == Result[Left,Right]
    assert_equal(success._ok().value.unsafe_ptr() == Span(left).unsafe_ptr(),True)
    var failure = run[R2](pipeline[R](R.fail[Left](Span(left))).map_err(replace).get(),0)
    assert_equal(failure._err().value.unsafe_ptr() == Span(right).unsafe_ptr(),True)
    var state = run[S2](pipeline[S](S.pure(Span(left))).map_both(keep,replace).get(),Span(left))
    assert_equal(state._ok().value[0].unsafe_ptr() == Span(left).unsafe_ptr(),True)
    assert_equal(state._ok().value[1].unsafe_ptr() == Span(left).unsafe_ptr(),True)
    var logged = run_writer[W2](pipeline[W](W.fail[Left](Span(left))).map_err(replace).get())
    assert_equal(logged._err().value.unsafe_ptr() == Span(right).unsafe_ptr(),True)
    def raised(var error: Left) raises Right {ref right} -> Int: raise Span(right)
    var pending = pipeline[R](R.fail[Int](Span(left))).raising[Right]().map_err(raised).get()
    var same = False
    try: _ = run[ReaderT[ResultFamily[Int],Int]](pending^,0)
    except error:
        comptime assert type_of(error) == Right
        same = error.unsafe_ptr() == Span(right).unsafe_ptr()
    assert_equal(same,True)
    # Source exceptions depend on the actual environment origin, not witness origins.
    var calls = 0
    def size(var error: String) {mut calls} -> Int:
        calls += 1
        return error.byte_length()
    var native = pipeline[EnvRaises.Family](EnvRaises()).map_err(size).get()
    same = False
    try: _ = run[ReaderT[ResultFamily[Int],List[Int]]](native^,right)
    except error:
        comptime assert type_of(error) == Right
        same = error.unsafe_ptr() == Span(right).unsafe_ptr()
    assert_equal(same,True)
    assert_equal(calls,0)


comptime Inner = ReaderT[ResultFamily[String],Int]
comptime Outer = ReaderT[Inner,List[Int]]

@fieldwise_init
struct Held[o: ImmOrigin](ReaderAction):
    var owner: Pointer[List[Int],Self.o]
    comptime Family = Inner
    comptime Env = Int
    comptime Value = Int
    comptime Out[q: ImmOrigin] = Result[Int,String]
    def run[q: ImmOrigin](deinit self, ref[q] env: Int) -> Self.Out[q]:
        return Ok(self.owner[][0] + env)

@fieldwise_init
struct Retaining(ReaderAction,Defaultable):
    comptime Family = Outer
    comptime Env = List[Int]
    comptime Value = Int
    comptime Out[o: ImmOrigin] = Held[o]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]:
        return Held[o](Pointer(to=env))

def retained_environment() raises:
    var owner = List[Int]([8])
    comptime NextInner = ReaderT[ResultFamily[Int],Int]
    comptime NextOuter = ReaderT[NextInner,List[Int]]
    def size(var error: String) -> Int: return error.byte_length()
    var pending = pipeline[Outer](Retaining()).map_err(size).get()
    var inner = run[NextOuter](pending^,owner)
    comptime assert type_of(inner).S == Held[origin_of(owner)]
    assert_equal(run[NextInner](inner^,2)._ok().value,10)

def main() raises:
    origins(List[Int]([1,2]),List[Int]([3,4]))
    retained_environment()
