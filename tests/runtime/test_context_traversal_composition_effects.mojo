"""Postprocessing stays in the target effect; native errors and source pulls retain timing."""
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily, Traversable, Applicative
from fp.callables import UnaryContract
from fp.effects import Reader, run
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal
from algebra_support.iterators import Counted
from test_context_traversal_generic import ContextTraversalSource, ContextTraversalCompactFailure

def forward[A: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var A) raises E -> Optional[Optional[A]]](ref function: F, var source: List[A]) raises E -> Optional[List[A]]:
    return pipeline(source^).raising[E]().traverse_filter[OptionalFamily](function).get()

def forward_flat[A: Movable & Deinitable, B: Movable & Deinitable, E: Movable & Deinitable, //,
                 F: def(var A) raises E -> Optional[List[B]]](ref function: F, var source: List[A]) raises E -> Optional[List[B]]:
    return pipeline(source^).raising[E]().flat_traverse[OptionalFamily](function).get()

def forward_result[A: Movable & Deinitable, B: Movable & Deinitable, X: Movable & Deinitable, E: Movable & Deinitable, //,
                   F: def(var A) raises E -> Optional[B]](ref function: F, var source: Result[A,X]) raises E -> Optional[Result[NoneType,X]]:
    return pipeline(source^).raising[E]().traverse_void[OptionalFamily](function).get()

def select(var value: Int) raises Int -> Optional[Optional[Int]]:
    if value < 0: raise value
    return Optional(Optional(value) if value % 2 == 0 else Optional[Int]())

struct ResultTraversalFailure(Traversable):
    """An explicit Result source keeps its own traversal error contract."""
    comptime Native = ResultFamily[String]
    comptime Element[V: Movable & Deinitable] = Self.Native.Element[V]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Native.Mapped[V,F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Native.MapError[V,F]
    comptime Traversed[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Native.Traversed[G,V,F]
    comptime TraverseError[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ContextTraversalCompactFailure
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.MapError[V,F] -> Self.Mapped[V,F]:
        return Self.Native.map(f^, value^)
    @staticmethod
    def traverse[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.TraverseError[G,V,F] -> Self.Traversed[G,V,F]:
        raise ContextTraversalCompactFailure(23)

def main() raises:
    var selected: Optional[List[Int]]
    try: selected = forward(select, List[Int]([1,2,3]))
    except _: raise Error("unexpected native error")
    assert_equal(selected.value(), List[Int]([2]))
    var code = 0
    try: _ = forward(select, List[Int]([1,-2,3]))
    except error: code = error
    assert_equal(code, -2)
    def expand(var value: Int) -> Optional[List[String]]: return Optional(List[String]([String(value)]))
    assert_equal(forward_flat(expand, List[Int]([1,2])).value(), List[String](["1","2"]))
    assert_equal(forward_result(expand, Result[Int,String](Err(String("source")))).value()._err().value, "source")
    var completed: Optional[Result[NoneType,String]]
    try: completed = forward_result(select, Result[Int,String](Ok(2)))
    except _: raise Error("unexpected native error")
    assert_equal(completed.value().is_ok(), True)
    try: _ = forward_result(select, Result[Int,String](Ok(-3)))
    except error: code = error
    assert_equal(code, -3)
    try: _ = pipeline[ResultTraversalFailure](Result[Int,String](Ok(1))).traverse_void[OptionalFamily](expand).get()
    except error:
        comptime assert type_of(error) == ContextTraversalCompactFailure
        code = error.code
    assert_equal(code, 23)

    var calls = ArcPointer(0)
    comptime Deferred = Reader[Int]
    def later(var value: Int) {calls} -> Deferred.Pure[Optional[Int]]:
        calls[] += 1
        return Deferred.pure(Optional(value) if value == 2 else Optional[Int]())
    var pending = pipeline(List[Int]([1,2,3])).traverse_filter[Deferred](later).get()
    assert_equal(calls[], 0)
    assert_equal(run[Deferred](pending^, 0), List[Int]([2]))
    assert_equal(calls[], 3)
    calls[] = 0
    var custom = pipeline[ContextTraversalSource](List[Int]([1,2])).traverse_filter[Deferred](later).get()
    assert_equal(calls[], 0)
    try: _ = run[Deferred](custom^, 0)
    except error:
        comptime assert type_of(error) == ContextTraversalCompactFailure
        code = error.code
    assert_equal(code, 99); assert_equal(calls[], 2)
    calls[] = 0
    def fail(var value: Int) raises Int {calls} -> Deferred.Pure[Optional[Int]]:
        calls[] += 1
        if value == 2: raise value
        return Deferred.pure(Optional(value))
    var failing = pipeline(List[Int]([1,2,3])).raising[Int]().traverse_filter[Deferred](fail).get()
    assert_equal(calls[], 0)
    try: _ = run[Deferred](failing^, 0)
    except error: code = error
    assert_equal(code, 2); assert_equal(calls[], 2)

    var pulls = 0
    def stop(var value: Int) -> Result[Int,String]:
        if value == 2: return Err(String("stop"))
        return Ok(value)
    assert_equal(pipeline(Counted(Pointer(to=pulls),0,5)).traverse_void[ResultFamily[String]](stop).get()._err().value, "stop")
    assert_equal(pulls, 2)
    calls[] = 0; pulls = 0
    var discarded = pipeline(Counted(Pointer(to=pulls),0,3)).traverse_void[Deferred](later).get()
    assert_equal(calls[], 0); assert_equal(pulls, 0)
    _ = run[Deferred](discarded^, 0)
    assert_equal(calls[], 3); assert_equal(pulls, 4)
    def native_stop(var value: Int) raises StopIteration -> Optional[Int]: raise StopIteration()
    var raised = False
    try: _ = pipeline(range(3)).raising[StopIteration]().traverse_void[OptionalFamily](native_stop).get()
    except StopIteration: raised = True
    assert_equal(raised, True)
