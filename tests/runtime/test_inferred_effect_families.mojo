"""Declared recipe families drive pipeline, traversal and continuation inference."""
from fp.algebra import IdentityFamily, ListFamily, StringMonoid
from fp.effects import Reader, ReaderAction, ReaderT, State, Writer, IO, ResultT, ask, get, writer, delay, run, run_writer, run_io
from fp.functions import Pipeline, pipeline
from fp.data import Result
from fp.callables import Unary
from std.testing import assert_equal

def twice(var value: Int) -> Int: return value * 2
def read() -> Int: return 21

comptime R = Reader[Int]
comptime S = State[Int]
comptime W = Writer[StringMonoid]
def reader(var value: Int) -> R.Pure[Int]: return R.pure(value)
def state(var value: Int) -> S.Pure[Int]: return S.pure(value)
def text(var value: Int) -> R.Pure[String]: return R.pure(String(value))
def positive(value: Int) -> R.Pure[Bool]: return R.pure(value > 0)
def add(var acc: Int, var value: Int) -> R.Pure[Int]: return R.pure(acc + value)
def optional(var value: Int) -> R.Pure[Optional[Int]]: return R.pure(Optional(value) if value > 0 else Optional[Int]())

@fieldwise_init
struct Bare(Movable):
    # A field with this name alone does not declare effect-carrier membership.
    comptime Family = R
    var value: Int

@fieldwise_init
struct Extract(Unary):
    comptime Arg = Bare
    comptime Out = Int
    def call(self, var value: Bare) -> Int: return value.value

def whole(var recipe: R.Pure[Int]) -> Int:
    return run[R](recipe^, 0)

def selected[C: ReaderAction](var recipe: C) -> Pipeline[C.Family, C]:
    return pipeline(recipe^)

def main() raises:
    var r = selected(ask[R]()).map(twice).get()
    assert_equal(run[R](r^, 3), 6)
    var s = pipeline(get[S]()).map(twice).get()
    assert_equal(run[S](s^, 3), (6, 3))
    var w = pipeline(writer[W, Int]((String("log"), 3))).map(twice).get()
    assert_equal(run_writer[W](w^), (String("log"), 6))
    var io = pipeline(delay[Error](read)).map(twice).get()
    var outcome = run_io(io^)
    assert_equal(outcome.take().get_or(0), 42)
    var readers = pipeline[Int]([1, 2]).traverse(reader).get()
    assert_equal(run[R](readers^, 0), [1, 2])
    var states = pipeline[Int]([1, 2]).traverse(state).get()
    var pair = run[S](states^, 7)
    assert_equal(pair[0], [1, 2])
    assert_equal(pair[1], 7)
    var continued = pipeline(1).then(reader).map(twice).get()
    assert_equal(run[R](continued^, 0), 2)
    var explicit = pipeline[IdentityFamily](R.pure(1))
    comptime assert type_of(explicit).I == IdentityFamily
    assert_equal(explicit^.map(whole).get(), 1)
    assert_equal(pipeline(3).map(twice).get(), 6)
    assert_equal(pipeline(R.pure(3)).then(whole).get(), 3)
    assert_equal(pipeline(Bare(3)).map(Extract()).get(), 3)
    comptime Nested = ReaderT[S, Int]
    var outer = pipeline(ask[Nested]()).map(twice).get()
    var inner = pipeline(run[Nested](outer^, 4)).map(twice).get()
    assert_equal(run[S](inner^, 9), (16, 9))

    # Erased transformer layers still need an explicit semantic selection.
    comptime T = ResultT[R, String]
    var base = pipeline(T.pure(7))
    comptime assert type_of(base).I == R
    var untouched = run[R](base^.get(), 0)
    assert_equal(untouched^.get_or(0), 7)
    var selected = pipeline[T](T.pure(7)).map(twice).get()
    assert_equal(run[R](selected^, 0).get_or(0), 14)

    var effects = List[R.Pure[Int]]()
    effects.append(R.pure(3))
    effects.append(R.pure(4))
    var sequenced = pipeline(effects^).sequence().get()
    assert_equal(run[R](sequenced^, 0), [3, 4])

    var calls = 0
    def counted(var value: Int) {mut calls} -> R.Pure[Int]:
        calls += 1
        return R.pure(value)
    var deferred = pipeline[Int]([5, 6]).traverse(counted).get()
    assert_equal(calls, 0)
    assert_equal(run[R](deferred^, 0), [5, 6])
    assert_equal(calls, 2)
    var empty = pipeline(List[Int]()).traverse(counted).get()
    assert_equal(run[R](empty^, 0), List[Int]())
    assert_equal(calls, 2)

    var folded = pipeline[Int]([1, 2]).fold_map_effect[StringMonoid](text).get()
    assert_equal(run[R](folded^, 0), "12")
    var empty_combination = pipeline(List[R.Pure[String]]()).combine_all_effect[StringMonoid]().get()
    assert_equal(run[R](empty_combination^, 0), "")
    var words = List[R.Pure[String]]()
    words.append(R.pure(String("one")))
    words.append(R.pure(String("two")))
    var combination = pipeline(words^).combine_all_effect[StringMonoid]().get()
    assert_equal(run[R](combination^, 0), "onetwo")
    var accumulated = pipeline[Int]([1, 2]).fold_effect(3).run(add).get()
    assert_equal(run[R](accumulated^, 0), 6)
    var filtered = pipeline[Int]([-1, 2, 3]).filter_effect(positive).get()
    assert_equal(run[R](filtered^, 0), [2, 3])
    var found = pipeline[Int]([-1, 2, 3]).find_map_effect(optional).get()
    var selected_value = run[R](found^, 0)
    assert_equal(selected_value.value(), 2)
