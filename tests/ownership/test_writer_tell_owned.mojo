"""Log appending moves payloads; repeated branches copy only the bound log."""
from fp.algebra import Monoid, ListFamily, ResultFamily, fail
from fp.effects import Writer, WriterT, Reader, writer, TellContract
from fp.functions import pipeline
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct Owned(Movable):
    var number: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


struct OwnedLog(Monoid):
    comptime Value = Owned
    @staticmethod
    def empty() -> Owned: return Owned(0,ArcPointer(0))
    @staticmethod
    def combine(var left: Owned, var right: Owned) -> Owned:
        left.number = left.number * 10 + right.number
        return left^


@fieldwise_init
struct CountedLog(Copyable):
    var text: String
    var copies: ArcPointer[Int]
    def __init__(out self, *, copy: Self):
        self.text = copy.text.copy()
        self.copies = copy.copies
        self.copies[] += 1


struct CopyLog(Monoid):
    comptime Value = CountedLog
    @staticmethod
    def empty() -> CountedLog: return CountedLog("",ArcPointer(0))
    @staticmethod
    def combine(var left: CountedLog, var right: CountedLog) -> CountedLog:
        left.text += right.text
        return left^


struct FailingOwnedLog(Monoid):
    comptime Value = Owned
    comptime Error = Int
    @staticmethod
    def empty() raises Int -> Owned: raise 99
    @staticmethod
    def combine(var left: Owned, var right: Owned) raises Int -> Owned: raise 71


def single(logs: ArcPointer[Int], payloads: ArcPointer[Int], abandon: Bool) raises:
    comptime R = Reader[Int]
    comptime W = WriterT[R,OwnedLog]
    var source = writer[W,Owned](R.pure((Owned(1,logs),Owned(7,payloads))))
    comptime assert TellContract[W,type_of(source)].Compatible
    var pending = pipeline(source^).tell(Owned(2,logs)).run()
    comptime assert not conforms_to(type_of(pending),Copyable)
    assert_equal(logs[],0)
    assert_equal(payloads[],0)
    if abandon:
        _ = pending^
        return
    var result = pipeline(pending^).run(0)
    assert_equal(logs[],1)
    assert_equal(payloads[],0)
    assert_equal(result[0].number,12)
    assert_equal(result[1].number,7)


def repeated(copies: ArcPointer[Int], payloads: ArcPointer[Int]) raises:
    comptime W = WriterT[ListFamily,CopyLog]
    var values = List[Tuple[CountedLog,Owned]]()
    values.append((CountedLog("a",copies),Owned(1,payloads)))
    values.append((CountedLog("b",copies),Owned(2,payloads)))
    var source = writer[W,Owned](values^)
    var results = pipeline(source^).tell(CountedLog("!",copies)).run()
    assert_equal(copies[],2)
    assert_equal(payloads[],0)
    assert_equal(results[0][0].text,"a!")
    assert_equal(results[1][0].text,"b!")
    assert_equal(results[0][1].number,1)
    assert_equal(results[1][1].number,2)
    var empty = writer[W,Owned](List[Tuple[CountedLog,Owned]]())
    assert_equal(len(pipeline(empty^).tell(CountedLog("!",copies)).run()),0)
    assert_equal(copies[],2)


def skipped_and_failed(logs: ArcPointer[Int], payloads: ArcPointer[Int]) raises:
    comptime Skip = WriterT[ResultFamily[String],OwnedLog]
    var skipped = pipeline(fail[Skip,Owned](String("skip"))).tell(Owned(2,logs)).run()
    assert_equal(skipped._err().value,"skip")
    assert_equal(logs[],1)
    comptime Fail = Writer[FailingOwnedLog]
    var code = 0
    try:
        _ = pipeline(writer[Fail,Owned]((Owned(1,logs),Owned(7,payloads)))).tell(Owned(2,logs))
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,71)
    assert_equal(logs[],3)
    assert_equal(payloads[],1)


def main() raises:
    for abandon in range(2):
        var logs = ArcPointer(0)
        var payloads = ArcPointer(0)
        single(logs,payloads,abandon != 0)
        assert_equal(logs[],2)
        assert_equal(payloads[],1)
    var copies = ArcPointer(0)
    var payloads = ArcPointer(0)
    repeated(copies,payloads)
    assert_equal(copies[],2)
    assert_equal(payloads[],2)
    skipped_and_failed(ArcPointer(0),ArcPointer(0))
