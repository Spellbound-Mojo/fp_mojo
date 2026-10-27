from fp.algebra import Monoid
from fp.callables import RepeatableUnary, call_once, call_repeated
from fp.effects.writer import _Prepend
from test_context_writer_receivers_ownership import Owner, LogItem, Log
from std.memory import ArcPointer
from std.testing import assert_equal

struct MoveLog[fail: Bool](Monoid):
    comptime Value = Owner
    comptime Error = Int
    @staticmethod
    def empty() raises Int -> Owner:
        raise 50
    @staticmethod
    def combine(var left: Owner, var right: Owner) raises Int -> Owner:
        left.trace[] += "w"
        if Self.fail:
            raise 71
        return left^

def move_prefix[fail: Bool]() raises:
    var trace = ArcPointer(String())
    comptime F = _Prepend[MoveLog[fail], Owner]
    comptime assert not RepeatableUnary[F] and not conforms_to(F, Copyable)
    var code = 0
    try:
        var result = call_once(F(Owner(1, trace)), Tuple(Owner(2, trace), Owner(3, trace)))
        _ = result^
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 71 if fail else 0)
    assert_equal(trace[], "2w13")

def copy_prefix[fail: Bool, repeated: Bool]() raises:
    var trace = ArcPointer(String())
    comptime F = _Prepend[Log[fail], Owner]
    comptime assert RepeatableUnary[F] and conforms_to(F, Copyable)
    var f = F(LogItem(1, trace))
    var code = 0
    comptime if repeated:
        for _ in range(2):
            try:
                var result = call_repeated(f, Tuple(LogItem(2, trace), Owner(3, trace)))
                _ = result^
            except error:
                comptime assert type_of(error) == Int
                code = error
        _ = f^
    else:
        try:
            var result = call_once(f^, Tuple(LogItem(2, trace), Owner(3, trace)))
            _ = result^
        except error:
            comptime assert type_of(error) == Int
            code = error
    assert_equal(code, 71 if fail else 0)
    assert_equal(trace[], "p2w13p2w131" if repeated else "2w13")

def main() raises:
    move_prefix[False]()
    move_prefix[True]()
    copy_prefix[False, False]()
    copy_prefix[True, False]()
    copy_prefix[False, True]()
    copy_prefix[True, True]()
