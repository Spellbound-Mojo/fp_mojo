"""Explicit sequence families preserve shape across changing payload types."""
from std.collections import Array, Deque, LinkedList
from std.testing import assert_equal
from fp.algebra import ArrayFamily, DequeFamily, LinkedListFamily, Functor, Applicative
from fp.algebra.instances import _NativeFamily, _InferredApplicative
from fp.algebra import IdentityFamily, ListFamily, OptionalFamily, ResultFamily
from fp.callables import UnaryContract
from fp.data import Result
from fp.functions import pipeline, Identity

def label(var value: Int) -> String: return String(value)
def size(var value: String) -> Int: return value.byte_length()
def positive(value: Int) -> Bool: return value > 0
def present(var value: Int) -> Optional[String]:
    return Optional(String(value)) if value > 0 else None
def length(var value: Array[Int, 2]) -> Int: return len(value)

def generic[I: Functor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var value: V, var function: F
) raises I.MapError[V, F] -> I.Mapped[V, F] where I.Element[V] == F.Arg and I.MapCompatible[V, F]:
    return pipeline[I](value^).map(function^).get()

def main() raises:
    comptime assert conforms_to(ArrayFamily[2], Functor)
    comptime assert not conforms_to(ArrayFamily[2], Applicative)
    # Recognition permits a map-only fallback; legacy Applicative defaults stay.
    comptime assert _NativeFamily[Int, ArrayFamily[2]] == ArrayFamily[2]
    comptime assert _NativeFamily[List[Int], ArrayFamily[2]] == ListFamily
    comptime assert _InferredApplicative[Int] == OptionalFamily
    comptime assert _InferredApplicative[Result[Int, String]] == ResultFamily[String]
    var array: Array[Int, 2] = [7, 42]
    var mapped = pipeline[ArrayFamily[2]](array^).map(label).map(size).get()
    comptime assert type_of(mapped) == Array[Int, 2]
    assert_equal(mapped[0], 1)
    assert_equal(mapped[1], 2)
    var whole: Array[Int, 2] = [1, 2]
    assert_equal(pipeline(whole^).map(length).get(), 2)
    var deque = Deque[Int]()
    deque.append(0)
    deque.append(42)
    var filtered = pipeline[DequeFamily](deque^).filter(positive).filter_map(present).map(size).get()
    comptime assert type_of(filtered) == Deque[Int]
    assert_equal(filtered.pop(), 2)
    var linked = LinkedList[Int]()
    linked.append(3)
    linked.append(42)
    var changed = pipeline[LinkedListFamily](linked^).map(label).map(size).get()
    assert_equal(List(changed), List[Int]([1, 2]))
    var forwarded = generic[LinkedListFamily](changed^, Identity[Int]())
    assert_equal(List(forwarded), List[Int]([1, 2]))
    var bad: Array[Int, 2] = [7, -9]
    var code = 0
    try:
        _ = pipeline[ArrayFamily[2]](bad^).raising[Failure]().map(checked).get()
    except error:
        comptime assert type_of(error) == Failure
        code = error.code
    assert_equal(code, -9)

@fieldwise_init
struct Failure(Movable):
    var code: Int

def checked(var value: Int) raises Failure -> String:
    if value < 0: raise Failure(value)
    return String(value)
