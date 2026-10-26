"""Native errors, thin pointers and deferred callback errors keep their exact timing."""
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Ok
from fp.effects import Reader, run
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct ContextTraversalFault(Movable):
    var code: Int

def decide(value: Int) -> Optional[Bool]: return Optional(value % 2 == 0)
def never(value: Int) raises Never -> Optional[Bool]: return Optional(value % 2 == 0)
def checked(value: Int) raises ContextTraversalFault -> Optional[Bool]:
    if value == 3: raise ContextTraversalFault(value)
    return Optional(True)

def string_decide(value: String) -> Optional[Bool]: return Optional(value.byte_length() > 1)

def exact_never() -> Optional[List[Int]]:
    var pointer: def(Int) thin -> Optional[Bool] = decide
    var never_pointer: def(Int) raises Never thin -> Optional[Bool] = never
    var retained = pipeline(List[Int]([1, 2, 3])).raising[ContextTraversalFault]().traverse_tap[OptionalFamily](pointer).get()
    var values = retained.take()
    return pipeline(values^).raising[ContextTraversalFault]().filter_effect[OptionalFamily](never_pointer).get()

def main() raises:
    assert_equal(exact_never().value(), List[Int]([2]))
    var string_pointer: def(String) thin -> Optional[Bool] = string_decide
    var strings = pipeline(List[String](["a", "ab"])).traverse_tap[OptionalFamily](string_pointer).get()
    assert_equal(strings.value(), List[String](["a", "ab"]))
    assert_equal(pipeline(strings.take()).filter_effect[OptionalFamily](string_pointer).get().value(), List[String](["ab"]))
    var native: def(Int) raises ContextTraversalFault thin -> Optional[Bool] = checked
    var code = 0
    try: _ = pipeline(List[Int]([1, 2, 3, 4])).raising[ContextTraversalFault]().filter_effect[OptionalFamily](native).get()
    except error:
        comptime assert type_of(error) == ContextTraversalFault
        code = error.code
    assert_equal(code, 3)
    var calls = ArcPointer(List[Int]())
    def fail(value: Int) raises ContextTraversalFault {calls} -> Result[Int, String]:
        calls[].append(value)
        if value == 2: raise ContextTraversalFault(20)
        return Ok(value)
    try: _ = pipeline(List[Int]([1, 2, 3])).raising[ContextTraversalFault]().traverse_tap[ResultFamily[String]](fail).get()
    except error: code = error.code
    assert_equal(code, 20)
    assert_equal(calls[], List[Int]([1, 2]))

    comptime Deferred = Reader[Int]
    calls[].clear()
    def deferred(value: Int) {calls} -> Deferred.Pure[Bool]:
        calls[].append(value)
        return Deferred.pure(value % 2 == 0)
    var pending = pipeline(List[Int]([1, 2, 3, 4])).filter_effect[Deferred](deferred).get()
    assert_equal(len(calls[]), 0)
    var output = run[Deferred](pending^, 0)
    assert_equal(output, List[Int]([2, 4]))
    assert_equal(calls[], List[Int]([1, 2, 3, 4]))
    calls[].clear()
    var untouched = pipeline(List[Int]([1, 2])).traverse_tap[Deferred](deferred).get()
    _ = untouched^
    assert_equal(len(calls[]), 0)
    def delayed_failure(value: Int) raises ContextTraversalFault {calls} -> Deferred.Pure[Bool]:
        calls[].append(value)
        if value == 2: raise ContextTraversalFault(40)
        return Deferred.pure(True)
    # Constructing the deferred computation does not raise its callback error.
    var later = pipeline(List[Int]([1, 2, 3])).raising[ContextTraversalFault]().filter_effect[Deferred](delayed_failure).get()
    assert_equal(len(calls[]), 0)
    try: _ = run[Deferred](later^, 0)
    except error: code = error.code
    assert_equal(code, 40)
    assert_equal(calls[], List[Int]([1, 2]))

