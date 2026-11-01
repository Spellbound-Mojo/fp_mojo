"""Traversal and multi-input chains retain their canonical family semantics."""
from fp.functions import pipeline
from fp.algebra import ResultFamily, OptionalFamily
from fp.data import Result, Ok, Err
from fp.callables import OnceBinary, OnceUnary
from std.testing import assert_equal
@fieldwise_init
struct ContextStagesCombineFault(Movable):
    var code: Int
@fieldwise_init
struct ContextStagesPair(OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call_once(deinit self, var a: Int, var b: Int) -> Int: return a + b
@fieldwise_init
struct ContextStagesTuple(OnceUnary):
    comptime Arg = Tuple[Int, Int]
    comptime Out = Int
    def call_once(deinit self, var xs: Self.Arg) -> Int: return xs[0] + xs[1]
def add(var a: Int, var b: Int) -> Int: return a + b
def sub(var a: Int, var b: Int) -> Int: return a - b
def never_add(var a: Int, var b: Int) raises Never -> Int: return a + b
def fail(var a: Int, var b: Int) raises ContextStagesCombineFault -> Int: raise ContextStagesCombineFault(a + b)
def checked(var x: Int) -> Result[Int, String]:
    if x == 3: return Err(String("third"))
    return Ok(x * 2)
def never_checked(var x: Int) raises Never -> Result[Int, String]: return Ok(x)
def raising_checked(var x: Int) raises ContextStagesCombineFault -> Result[Int, String]:
    raise ContextStagesCombineFault(x)
def count(var xs: List[Int]) -> Int: return len(xs)
def one(var x: Int) -> Int: return x + 1

def pure_chain() -> Int:
    return pipeline(Optional(2)).raising[ContextStagesCombineFault]().map2(Optional(3), never_add).get().value()
def pure_traverse() -> Int:
    return pipeline(List[Int]([1, 2])).raising[ContextStagesCombineFault]().traverse[ResultFamily[String]](never_checked).map(count).get()._ok().value

def main() raises:
    assert_equal(pure_chain(), 5)
    assert_equal(pure_traverse(), 2)
    assert_equal(pipeline(List[Int]([1, 2])).map2(List[Int]([10, 20]), sub).get(), List[Int]([-9, -19, -8, -18]))
    var absent = pipeline(Optional[Int]()).map2(Optional(2), ContextStagesPair()).get()
    assert_equal(Bool(absent), False)
    var success = pipeline(Result[Int, String](Ok(2))).map2(Result[Int, String](Ok(3)), ContextStagesPair()).get()
    assert_equal(success._ok().value, 5)
    var message: String
    try:
        var skipped = pipeline(Result[Int, String](Err(String("first")))).raising[ContextStagesCombineFault]().map2(Result[Int, String](Err(String("second"))), fail)
        message = skipped^.get()._err().value
    except _: raise Error("skipped callback ran")
    assert_equal(message, "first")
    var calls = 0
    def trace(var value: Int) {mut calls} -> Result[Int, String]:
        calls += 1
        return checked(value)
    var bad = pipeline(List[Int]([1, 2, 3, 4])).traverse[ResultFamily[String]](trace).get()
    assert_equal(bad._err().value, "third")
    assert_equal(calls, 3)
    var seq = pipeline(List[Optional[Int]]([Optional(3), Optional(4)])).sequence[OptionalFamily]().map(count).get()
    assert_equal(seq.value(), 2)
    var code = 0
    try: _ = pipeline(List[Int]([7, 8])).raising[ContextStagesCombineFault]().traverse[ResultFamily[String]](raising_checked).get()
    except error: code = error.code
    assert_equal(code, 7)
    var pairs = pipeline(Optional(2)).product(Optional(3)).get()
    assert_equal(pairs.value()[0], 2)
    assert_equal(pairs.value()[1], 3)
    var combined = pipeline(Optional(2)).map_n((Optional(3),), ContextStagesTuple()).get()
    assert_equal(combined.value(), 5)
    assert_equal(pipeline(Optional(2)).map_n((), one).get().value(), 3)
    assert_equal(pipeline(Optional(2)).raising[ContextStagesCombineFault]().map_n((Optional(3),), never_add).get().value(), 5)
    assert_equal(pipeline(List[Int]([1, 2])).map_n((List[Int]([10, 20]),), sub).get(), List[Int]([-9, -19, -8, -18]))
    def eight(var a: Int, var b: Int, var c: Int, var d: Int, var e: Int, var f: Int, var g: Int, var h: Int) -> Int:
        return a + b + c + d + e + f + g + h
    assert_equal(pipeline(Optional(1)).map_n((Optional(2), Optional(3), Optional(4), Optional(5), Optional(6), Optional(7), Optional(8)), eight).get().value(), 36)
    var tupled = pipeline(Optional(1)).product_n((Optional(2), Optional(3))).get()
    assert_equal(tupled.value()[2], 3)
    def combine3(var a0: Int, var a1: Int, var a2: Int) -> Int: return a0 + a1 + a2
    assert_equal(pipeline(Optional(1)).map_n((Optional(2), Optional(3)), combine3).get().value(), 6)
    def combine4(var a0: Int, var a1: Int, var a2: Int, var a3: Int) -> Int: return a0 + a1 + a2 + a3
    assert_equal(pipeline(Optional(1)).map_n((Optional(2), Optional(3), Optional(4)), combine4).get().value(), 10)
    def combine5(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int) -> Int: return a0 + a1 + a2 + a3 + a4
    assert_equal(pipeline(Optional(1)).map_n((Optional(2), Optional(3), Optional(4), Optional(5)), combine5).get().value(), 15)
    def combine6(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int, var a5: Int) -> Int: return a0 + a1 + a2 + a3 + a4 + a5
    assert_equal(pipeline(Optional(1)).map_n((Optional(2), Optional(3), Optional(4), Optional(5), Optional(6)), combine6).get().value(), 21)
    def combine7(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int, var a5: Int, var a6: Int) -> Int: return a0 + a1 + a2 + a3 + a4 + a5 + a6
    assert_equal(pipeline(Optional(1)).map_n((Optional(2), Optional(3), Optional(4), Optional(5), Optional(6), Optional(7)), combine7).get().value(), 28)
