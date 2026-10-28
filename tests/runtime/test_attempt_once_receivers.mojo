"""Capture any library thunk through canonical receiver selection and exact metadata."""
from fp.callables import ThunkContract, Thunk, MutableThunk, OnceThunk, mut_ref
from fp.data import Capture, Result, attempt_once
from fp.functions import partial
from std.testing import assert_equal

struct Shared(Thunk):
    comptime Out = Int
    def __init__(out self): pass
    def call(self) -> Int: return 9

@fieldwise_init
struct Counter(MutableThunk):
    comptime Out = Int
    comptime Error = Int
    var calls: Int
    def call_mut(mut self) raises Int -> Int:
        self.calls += 1
        if self.calls % 2 == 1: raise self.calls
        return self.calls

@fieldwise_init
struct Modes(Thunk, MutableThunk, OnceThunk):
    comptime Out = Int
    var calls: Int
    def call(self) -> Int: return 1
    def call_mut(mut self) -> Int:
        self.calls += 1
        return 2
    def call_once(deinit self) -> Int: return 3

def capture[F: ThunkContract & Movable & Deinitable](var callback: F) -> Result[F.Out, F.Error]:
    return attempt_once(callback^)

def capture_context[F: ThunkContract & Movable & Deinitable](var callback: F) -> Result[F.Out, F.Error]:
    return Capture[String]().run(callback^)

def add(left: Int, right: Int) -> Int: return left + right

def main() raises:
    assert_equal(capture(Shared()).get_or(0), 9)
    assert_equal(attempt_once(partial(add, 2, 3)).get_or(0), 5)
    assert_equal(attempt_once(Counter(0)).swap().get_or(0), 1)
    var counter = Counter(0)
    assert_equal(capture(mut_ref(counter)).swap().get_or(0), 1)
    assert_equal(counter.calls, 1)
    assert_equal(attempt_once(mut_ref(counter)).get_or(0), 2)
    assert_equal(counter.calls, 2)
    assert_equal(attempt_once(Modes(0)).get_or(0), 3)
    var modes = Modes(0)
    assert_equal(attempt_once(mut_ref(modes)).get_or(0), 2)
    assert_equal(modes.calls, 1)

    assert_equal(capture_context(Shared()).get_or(0), 9)
    assert_equal(Capture[Error]().run(partial(add, 2, 3)).get_or(0), 5)
    assert_equal(capture_context(Counter(0)).swap().get_or(0), 1)
    var context = Capture[String]()
    var reused = Counter(0)
    assert_equal(context.run(mut_ref(reused)).swap().get_or(0), 1)
    assert_equal(context.run(mut_ref(reused)).get_or(0), 2)
    assert_equal(reused.calls, 2)
    assert_equal(context.run(Modes(0)).get_or(0), 3)
