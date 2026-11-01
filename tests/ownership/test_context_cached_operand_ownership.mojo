# Cached operands preserve construction, copy timing and cleanup on every path.
from fp.algebra.protocols import _Lazy
from fp.callables import OnceThunk
from std.testing import assert_equal
from std.memory import ArcPointer
from test_context_writer_receivers_ownership import Owner, LogItem

@fieldwise_init
struct Produce[fail: Bool](OnceThunk):
    var value: LogItem
    var capture: Owner
    comptime Out = LogItem
    comptime Error = Int
    def call_once(deinit self) raises Int -> LogItem:
        self.capture.trace[] += "t"
        if Self.fail:
            raise 71
        return self.value^

def scenario[fail: Bool](mode: Int, trace: ArcPointer[String]) -> Int:
    var cached = _Lazy(Produce[fail](LogItem(3, trace), Owner(5, trace)))
    if mode == 0:
        return 0
    try:
        if mode == 1:
            _ = cached^.take()
        else:
            _ = cached.copy_value()
            _ = cached.copy_value()
            if mode == 2:
                _ = cached^.take()
    except error:
        comptime assert type_of(error) == Int
        return error
    return 0

def cases[fail: Bool]() raises:
    for mode in range(4):
        var trace = ArcPointer(String())
        var code = scenario[fail](mode, trace)
        assert_equal(code, 71 if fail and mode != 0 else 0)
        var expected = "35" if mode == 0 else "t53" if fail or mode == 1 else "t5p3p33"
        assert_equal(trace[], expected)

def main() raises:
    cases[False]()
    cases[True]()
    var trace = ArcPointer(String())
    try:
        pure_copy(trace)
    except error:
        assert_equal(False, True)
    assert_equal(trace[], "p33")
    var value = 7
    borrowed[fail=False](value)
    borrowed[fail=True](value)

@fieldwise_init
struct PureProduce(OnceThunk):
    var value: LogItem
    comptime Out = LogItem
    def call_once(deinit self) -> LogItem:
        return self.value^

def pure_copy(trace: ArcPointer[String]) raises Int:
    var cached = _Lazy(PureProduce(LogItem(3, trace)))
    _ = cached.copy_value[Int]()

@fieldwise_init
struct Borrowed[o: ImmOrigin, fail: Bool](OnceThunk):
    var value: Pointer[Int, Self.o]
    comptime Out = Pointer[Int, Self.o]
    comptime Error = Pointer[Int, Self.o]
    def call_once(deinit self) raises Self.Error -> Self.Out:
        if Self.fail:
            raise self.value
        return self.value

def borrowed[o: ImmOrigin, fail: Bool](ref[o] value: Int) raises:
    var cached = _Lazy(Borrowed[o, fail](Pointer(to=value)))
    var caught = False
    var matched = False
    try:
        var first = cached.copy_value()
        var second = cached.copy_value()
        comptime assert type_of(first) == Pointer[Int, o]
        matched = first == Pointer(to=value) and second == first
    except error:
        comptime assert type_of(error) == Pointer[Int, o]
        caught = error == Pointer(to=value)
    assert_equal(caught, fail)
    assert_equal(matched, not fail)
