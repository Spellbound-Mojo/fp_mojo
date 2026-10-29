"""Selected capability scopes preserve laws, timing and public generic contracts."""
from fp.functions import pipeline, Pipeline
from fp.effects import Reader, Writer, WriterT, Local, Listen, Censor, ask, writer
from fp.algebra import Functor, StringMonoid
from fp.callables import BorrowCallContract, UnaryContract
from test_environment_capabilities import ECAdd
from test_writer_capabilities import WCWrap
from std.testing import assert_equal

def shifted(value: Int) -> Int: return value + 2
def twice(var value: Int) -> Int: return value * 2
def bracket(var log: String) -> String: return "[" + log + "]"
def rejected(value: Int) raises Int -> Int: raise value

def scoped[I: Functor & Local, V: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable](var source: Pipeline[I, V], var function: F) raises I.LocalError[V,F] -> Pipeline[I.Family,I.Localized[V,F]] where I.LocalCompatible[V] and F.Payload == I.Environment and F.Result == I.Environment:
    return source^.local(function^)

def heard[I: Functor & Listen, V: Movable & Deinitable](var source: Pipeline[I,V]) raises I.ListenError[V] -> Pipeline[I.Family,I.Listened[V]] where I.ListenCompatible[V]:
    return source^.listen()

def censored[I: Functor & Censor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var source: Pipeline[I,V], var function: F) raises I.CensorError[V,F] -> Pipeline[I.Family,I.Censored[V,F]] where I.CensorCompatible[V,F] and F.Arg == I.Log.Value and F.Out == I.Log.Value:
    return source^.censor(function^)

def main() raises:
    comptime R = Reader[Int]
    comptime W = Writer[StringMonoid]
    var env = 3
    assert_equal(pipeline(ask[R]()).map(twice).local(shifted).run(env), 10)
    assert_equal(env, 3)
    assert_equal(scoped(pipeline(ask[R]()), ECAdd(2)).run(env), 5)
    assert_equal(pipeline(ask[R]()).local(ECAdd(2)).local(ECAdd(3)).run(env), 8)
    assert_equal(pipeline(ask[R]()).local(shifted).followed_by(ask[R]).run(env), 3)
    var calls = 0
    def counted(value: Int) {mut calls} -> Int:
        calls += 1
        return value + 1
    var pending = pipeline(ask[R]()).local(counted)
    assert_equal(calls, 0)
    assert_equal(pending^.run(env), 4)
    assert_equal(calls, 1)
    var error_code = 0
    try:
        _ = pipeline(ask[R]()).raising[Int]().local(rejected).run(env)
    except error:
        comptime assert type_of(error) == Int
        error_code = error
    assert_equal(error_code, 3)
    assert_equal(env, 3)
    var result = pipeline(writer[W,Int]((String("log"),3))).listen().censor(bracket).run()
    assert_equal(result[0], "[log]")
    assert_equal(result[1], (3,String("log")))
    var generic = heard(censored(pipeline(writer[W,Int]((String("a"),7))), WCWrap())).run()
    assert_equal(generic[0], "[a]")
    assert_equal(generic[1], (7,String("[a]")))
    comptime WR = WriterT[R, StringMonoid]
    var changes = 0
    def counted_log(var log: String) {mut changes} -> String:
        changes += 1
        return "[" + log + "]"
    var logged = pipeline(writer[WR,Int](R.pure((String("a"),7)))).listen().censor(counted_log)
    assert_equal(changes, 0)
    var base = logged^.run()
    assert_equal(changes, 0)
    var evaluated = pipeline(base^).run(0)
    assert_equal(changes, 1)
    assert_equal(evaluated[0], "[a]")
    assert_equal(evaluated[1], (7,String("a")))
