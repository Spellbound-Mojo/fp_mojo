"""Selected native errors, exact Never and independent library errors survive observation."""
from fp.functions import pipeline
from fp.callables import BorrowCallable
from fp.data import Result, Ok, Err
from std.testing import assert_equal

@fieldwise_init
struct ContextObserversFault(Movable):
    var code: Int

@fieldwise_init
struct ContextObserversProject(BorrowCallable):
    comptime Payload = Int
    comptime Result = Int
    comptime Failure = ContextObserversFault
    def invoke(self, ref value: Int) raises Self.Failure capturing -> Int:
        if value == 2: raise ContextObserversFault(value)
        return value + 10

@fieldwise_init
struct ContextObserversPredicate(BorrowCallable):
    comptime Payload = Int
    comptime Result = Bool
    def invoke(self, ref value: Int) capturing -> Bool: return value == 2

def pure(value: Int) -> Int: return value + 1
def never(value: Int) raises Never -> Int: return value + 2
def pure_predicate(value: Int) -> Bool: return value == 1
def never_predicate(value: Int) raises Never -> Bool: return value == 2
def void(value: Int): pass
def never_void(value: Int) raises Never: pass

def exact_never() -> Int:
    # An enclosing non-raising function proves the chosen error stays Never.
    var pure_fn: def(Int) thin -> Int = pure
    var never_fn: def(Int) raises Never thin -> Int = never
    var p: def(Int) thin -> Bool = pure_predicate
    var n: def(Int) raises Never thin -> Bool = never_predicate
    var assert_value = pipeline(3).raising[ContextObserversFault]().tap(void).tap(never_void).tap(pure_fn).tap(never_fn).get()
    var a = pipeline(List[Int]([1, 2, 3])).raising[ContextObserversFault]().tap_each(pure_fn).tap_each(never_fn).filter_not(p).filter_not(n).get()
    var b = pipeline(Optional(4)).raising[ContextObserversFault]().pair_with(never_fn).get()
    var c = pipeline(Optional(5)).raising[ContextObserversFault]().pair_with(pure_fn).get()
    return assert_value + a[0] + b.value()[1] + c.value()[1]

def main() raises:
    assert_equal(exact_never(), 18)
    var calls = List[Int]()
    def fail(value: Int) raises ContextObserversFault {ref calls} -> Int:
        calls.append(value)
        if value == 2: raise ContextObserversFault(20)
        return value + 10
    def reject(value: Int) raises ContextObserversFault {ref calls} -> Bool:
        calls.append(value)
        if value == 2: raise ContextObserversFault(30)
        return False
    def inspect(value: Int) raises ContextObserversFault {ref calls}:
        calls.append(value)
        raise ContextObserversFault(40)
    var code = 0
    try: _ = pipeline(2).raising[ContextObserversFault]().tap(inspect).get()
    except error:
        comptime assert type_of(error) == ContextObserversFault
        code = error.code
    assert_equal(code, 40)
    assert_equal(calls, List[Int]([2]))
    calls.clear()
    try: _ = pipeline(List[Int]([1, 2, 3])).raising[ContextObserversFault]().tap_each(fail).get()
    except error: code = error.code
    assert_equal(code, 20)
    assert_equal(calls, List[Int]([1, 2]))
    calls.clear()
    try: _ = pipeline(List[Int]([1, 2, 3])).raising[ContextObserversFault]().pair_with(fail).get()
    except error: code = error.code
    assert_equal(code, 20)
    assert_equal(calls, List[Int]([1, 2]))
    calls.clear()
    try: _ = pipeline(List[Int]([1, 2, 3])).raising[ContextObserversFault]().filter_not(reject).get()
    except error: code = error.code
    assert_equal(code, 30)
    assert_equal(calls, List[Int]([1, 2]))
    # Stored failure skips the callback; a raised native error stays raised.
    calls.clear()
    var stored: String
    try: stored = pipeline(Result[Int, String](Err(String("kept")))).raising[ContextObserversFault]().tap_each(fail).get()._err().value
    except _: raise Error("stored error unexpectedly invoked observer")
    assert_equal(stored, "kept")
    assert_equal(len(calls), 0)
    try: _ = pipeline(Result[Int, String](Ok(2))).raising[ContextObserversFault]().pair_with(fail).get()
    except error: code = error.code
    assert_equal(code, 20)
    # Library callbacks keep their own error without selecting a native error.
    try: _ = pipeline(Optional(2)).pair_with(ContextObserversProject()).get()
    except error: code = error.code
    assert_equal(code, 2)
    var whole: Int
    var elements: List[Int]
    try:
        whole = pipeline(1).tap(ContextObserversProject()).get()
        elements = pipeline(List[Int]([1, 3])).tap_each(ContextObserversProject()).get()
    except _: raise Error("valid library observer unexpectedly failed")
    assert_equal(whole, 1)
    assert_equal(elements, List[Int]([1, 3]))
    assert_equal(pipeline(List[Int]([1, 2, 3])).filter_not(ContextObserversPredicate()).get(), List[Int]([1, 3]))

