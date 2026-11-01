"""Appending uses the base's timing and propagates exact monoid errors."""
from fp.algebra import Monoid
from fp.effects import TellContract, Writer, WriterT, Reader, writer
from fp.functions import pipeline
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct Log(Copyable):
    var text: String
    var calls: ArcPointer[Int]


struct Logging(Monoid):
    comptime Value = Log
    comptime Error = Int
    @staticmethod
    def empty() raises Int -> Log: raise 99
    @staticmethod
    def combine(var left: Log, var right: Log) raises Int -> Log:
        right.calls[] += 1
        if right.text == "fail": raise 71
        left.text += right.text
        return left^


def main() raises:
    comptime W = Writer[Logging]
    comptime R = Reader[Int]
    comptime WR = WriterT[R,Logging]
    var calls = ArcPointer(0)
    var source = writer[W,Int]((Log("a",calls),7))
    comptime assert TellContract[W,type_of(source)].Error == Int
    var result = pipeline(source^).tell(Log("b",calls)).run()
    assert_equal(result[0].text,"ab")
    assert_equal(result[1],7)
    assert_equal(calls[],1)
    var eager_code = 0
    try:
        _ = pipeline(writer[W,Int]((Log("a",calls),7))).tell(Log("fail",calls))
    except error:
        comptime assert type_of(error) == Int
        eager_code = error
    assert_equal(eager_code,71)
    for mode in range(3):
        calls[] = 0
        var value = writer[WR,Int](R.pure((Log("a",calls),7)))
        comptime assert TellContract[WR,type_of(value)].Error == Never
        var pending = pipeline(value^).tell(Log("fail" if mode == 1 else "b",calls)).run()
        assert_equal(calls[],0)
        if mode == 2:
            _ = pending^
            assert_equal(calls[],0)
            continue
        var code = 0
        var text = String()
        try:
            text = pipeline(pending^).run(0)[0].text
        except error:
            comptime assert type_of(error) == Int
            code = error
        assert_equal(code,71 if mode == 1 else 0)
        assert_equal(text,"" if mode == 1 else "ab")
        assert_equal(calls[],1)
