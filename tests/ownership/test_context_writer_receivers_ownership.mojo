# Repeated Writer calls retain the owned receiver; errors preserve cleanup order.
from fp.callables import OnceBinary, MutableBinary, MutableUnary, call_once, call_repeated
from fp.algebra import Monoid, IdentityFamily
from fp.effects.writer import WriterT, _WriterStep, _WriterCombine
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Owner(Movable):
    var id: Int
    var trace: ArcPointer[String]
    def __deinit__(deinit self):
        self.trace[] += String(self.id)

@fieldwise_init
struct LogItem(Copyable):
    var id: Int
    var trace: ArcPointer[String]
    def __init__(out self, *, copy: Self):
        self.id = copy.id
        self.trace = copy.trace
        self.trace[] += "p"
    def __deinit__(deinit self):
        self.trace[] += String(self.id)

struct Log[fail: Bool](Monoid):
    comptime Value = LogItem
    comptime Error = Int
    @staticmethod
    def empty() raises Int -> LogItem:
        raise 50
    @staticmethod
    def combine(var left: LogItem, var right: LogItem) raises Int -> LogItem:
        left.trace[] += "w"
        if Self.fail:
            raise 71
        return left^

@fieldwise_init
struct Combine[fail: Bool](MutableBinary):
    var capture: Owner
    var calls: Int
    comptime First = Owner
    comptime Second = Owner
    comptime Out = Owner
    comptime Error = Int
    def call_mut(mut self, var first: Owner, var second: Owner) raises Int -> Owner:
        self.calls += 1
        self.capture.trace[] += "c" + String(self.calls)
        if Self.fail:
            raise 83
        return first^

@fieldwise_init
struct Step[log_fail: Bool, fail: Bool](MutableUnary):
    var capture: Owner
    var calls: Int
    comptime I = WriterT[IdentityFamily, Log[Self.log_fail]]
    comptime Arg = Owner
    comptime Out = Self.I.Pure[Owner]
    comptime Error = Int
    def call_mut(mut self, var value: Owner) raises Int -> Self.Out:
        self.calls += 1
        self.capture.trace[] += "s" + String(self.calls)
        if Self.fail:
            raise 97
        return Self.Out(Tuple(LogItem(3, self.capture.trace), value^))

def combine[log_fail: Bool, fail: Bool, repeated: Bool]() raises:
    var trace = ArcPointer(String())
    var f = _WriterCombine[Log[log_fail], Combine[fail]](Combine[fail](Owner(5, trace), 0))
    var code = 0
    comptime if repeated:
        for _ in range(2):
            try:
                var result = call_repeated(f, Tuple(LogItem(1, trace), Owner(2, trace)), Tuple(LogItem(3, trace), Owner(4, trace)))
                _ = result^
            except error:
                comptime assert type_of(error) == Int
                code = error
        _ = f^
    else:
        try:
            var result = call_once(f^, Tuple(LogItem(1, trace), Owner(2, trace)), Tuple(LogItem(3, trace), Owner(4, trace)))
            _ = result^
        except error:
            comptime assert type_of(error) == Int
            code = error
    comptime assert not conforms_to(Combine[fail], Copyable)
    assert_equal(code, 71 if log_fail else 83 if fail else 0)
    var expected: String
    if log_fail:
        expected = "3w1423w1425" if repeated else "3w1542"
    elif fail:
        expected = "3w4c1213w4c2215" if repeated else "3w4c1251"
    else:
        expected = "3w4c1123w4c2125" if repeated else "3w4c1512"
    assert_equal(trace[], expected)

def step[log_fail: Bool, fail: Bool, repeated: Bool]() raises:
    var trace = ArcPointer(String())
    comptime I = WriterT[IdentityFamily, Log[log_fail]]
    var f = _WriterStep[I, Step[log_fail, fail]](Step[log_fail, fail](Owner(5, trace), 0))
    var code = 0
    comptime if repeated:
        for _ in range(2):
            try:
                var result = call_repeated(f, Tuple(LogItem(1, trace), Owner(2, trace)))
                _ = result^
            except error:
                comptime assert type_of(error) == Int
                code = error
        _ = f^
    else:
        try:
            var result = call_once(f^, Tuple(LogItem(1, trace), Owner(2, trace)))
            _ = result^
        except error:
            comptime assert type_of(error) == Int
            code = error
    comptime assert not conforms_to(Step[log_fail, fail], Copyable)
    assert_equal(code, 97 if fail else 71 if log_fail else 0)
    var expected: String
    if fail:
        expected = "s121s2215" if repeated else "s1251"
    else:
        expected = "s13w12s23w125" if repeated else "s153w12"
    assert_equal(trace[], expected)

def cases[log_fail: Bool, fail: Bool]() raises:
    combine[log_fail, fail, False]()
    combine[log_fail, fail, True]()
    step[log_fail, fail, False]()
    step[log_fail, fail, True]()

def main() raises:
    cases[False, False]()
    cases[True, False]()
    cases[False, True]()
    cases[True, True]()
