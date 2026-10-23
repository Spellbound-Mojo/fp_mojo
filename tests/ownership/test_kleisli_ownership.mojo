"""Kleisli moves callbacks and payloads, including deferred continuations."""
from fp.functions import kleisli, piped
from fp.iteration import iterated
from fp.algebra import ResultFamily
from fp.effects import Reader, run
from fp.data import Result, Ok, Err
from fp.callables import Unary, OnceUnary
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true

@fieldwise_init
struct KOwner(Movable):
    var text: String
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct KConsume(OnceUnary):
    var capture: KOwner
    comptime Arg = KOwner
    comptime Out = Result[KOwner, String]
    def call_once(deinit self, var arg: KOwner) -> Self.Out:
        arg.text += self.capture.text
        return Ok(arg^)

@fieldwise_init
struct KExtract(OnceUnary):
    comptime Arg = KOwner
    comptime Out = String
    def call_once(deinit self, var arg: KOwner) -> String: return arg.text.copy()

def ko_accept(var owner: KOwner) -> Result[KOwner, String]:
    if owner.text == "fail": return Err(String("rejected"))
    return Ok(owner^)

def ko_raise(var owner: KOwner) raises Int -> Result[KOwner, String]: raise 7

def ko_immediate() raises:
    var drops = ArcPointer(0)
    var chain = kleisli[ResultFamily[String]](ko_accept).then(KConsume(KOwner("!", drops))).map(KExtract())
    assert_equal(chain^.call_once(KOwner("hello", drops)).raise_on_err(), "hello!")
    assert_equal(drops[], 2)
    var skipped = kleisli[ResultFamily[String]](ko_accept).then(KConsume(KOwner("unused", drops)))
    assert_true(skipped^.call_once(KOwner("fail", drops)).is_err())
    assert_equal(drops[], 4)
    var raised = kleisli[ResultFamily[String]](ko_raise).then(KConsume(KOwner("unused", drops)))
    var code = 0
    try:
        _ = raised^.call_once(KOwner("native", drops))
    except error: code = error
    assert_equal(code, 7)
    assert_equal(drops[], 6)

@fieldwise_init
struct KReaderConsume(OnceUnary):
    var capture: KOwner
    comptime Arg = Int
    comptime Out = Reader[Int].Pure[Int]
    def call_once(deinit self, var arg: Int) -> Self.Out:
        return Reader[Int].pure(arg + self.capture.text.byte_length())

@fieldwise_init
struct KReaderShared(Unary):
    var capture: KOwner
    comptime Arg = Int
    comptime Out = Reader[Int].Pure[Int]
    def call(self, var arg: Int) -> Self.Out:
        return Reader[Int].pure(arg + self.capture.text.byte_length())

def ko_reader(x: Int) -> Reader[Int].Pure[Int]: return Reader[Int].pure(x)

def ko_deferred() raises:
    var drops = ArcPointer(0)
    var chain = kleisli[Reader[Int]](ko_reader).then(KReaderConsume(KOwner("abc", drops)))
    var effect = chain^.call_once(4)
    assert_equal(drops[], 0)
    assert_equal(run[Reader[Int]](effect^, 0), 7)
    assert_equal(drops[], 1)
    var abandoned = kleisli[Reader[Int]](ko_reader).then(KReaderConsume(KOwner("def", drops))).call_once(4)
    _ = abandoned^
    assert_equal(drops[], 2)
    var shared = kleisli[Reader[Int]](ko_reader).then(KReaderShared(KOwner("abcd", drops)))
    var borrowed = shared.call(4)
    assert_equal(drops[], 2)
    assert_equal(run[Reader[Int]](borrowed^, 0), 8)
    assert_equal(run[Reader[Int]](shared.call(5), 0), 9)
    _ = shared^
    assert_equal(drops[], 3)

def ko_views() raises:
    var drops = ArcPointer(0)
    var chain = kleisli[Reader[Int]](ko_reader).then(KReaderShared(KOwner("abc", drops)))
    var values: List[Int] = [1, 2]
    var actions = iterated(values^).map(chain).collect_list()
    var second = actions.pop()
    var first = actions.pop()
    assert_equal(run[Reader[Int]](first^, 0), 4)
    assert_equal(run[Reader[Int]](second^, 0), 5)
    assert_equal(drops[], 0)
    var eager = piped(Optional(3)).map(chain).get()
    assert_equal(run[Reader[Int]](eager.take(), 0), 6)
    _ = chain^
    assert_equal(drops[], 1)


def main() raises:
    ko_immediate()
    ko_deferred()
    ko_views()
