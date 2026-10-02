"""Finite evidence for pure, terminating transformations; not semantic proofs."""
from fp.algebra import map, ResultFamily
from fp.functions import pipe, as_unary, identity
from fp.data import Result, Ok, Err
from std.builtin.variadics import TypeList
from std.memory import ArcPointer
from std.testing import assert_equal

def id_int(var value: Int) -> Int: return identity(value)
def next_int(var value: Int) -> Int: return value + 1
def text(var value: Int) -> String: return "v=" + String(value)
def size(var value: String) -> Int: return value.byte_length()
def length_after_next(var value: Int) -> Int: return size(text(next_int(value)))
def next_text(var value: Int) -> String: return text(next_int(value))
def text_size(var value: Int) -> Int: return size(text(value))

def pipeline(value: Int) raises:
    var id = as_unary(id_int)
    var add = as_unary(next_int)
    var show = as_unary(text)
    var length = as_unary(size)
    var add_show = as_unary(next_text)
    var show_length = as_unary(text_size)
    comptime Full = TypeList.of[Trait=Movable & Deinitable, Int, String, Int]()
    comptime Left = TypeList.of[Trait=Movable & Deinitable, String, Int]()
    comptime Right = TypeList.of[Trait=Movable & Deinitable, Int, Int]()
    assert_equal(pipe(value, id), value)
    assert_equal(pipe[Right](value, id, add), pipe(value, add))
    assert_equal(pipe[Right](value, add, id), pipe(value, add))
    var result = pipe[Full](value, add, show, length)
    assert_equal(result, pipe[Left](value, add_show, length))
    assert_equal(result, pipe[Right](value, add, show_length))
    assert_equal(result, length_after_next(value))

def optional_equal(a: Optional[String], b: Optional[String]) raises:
    assert_equal(Bool(a), Bool(b))
    if a: assert_equal(a.value(), b.value())

def optional_laws(value: Int) raises:
    for present in range(2):
        var subject = Optional(value) if present else Optional[Int]()
        var unchanged = subject.copy().map(id_int)
        assert_equal(Bool(unchanged), Bool(subject))
        if subject: assert_equal(unchanged.value(), subject.value())
        optional_equal(subject.copy().map(next_int).map(text), subject.copy().map(next_text))

def show_ok(value: String) -> String: return "ok:" + value
def show_err(value: String) -> String: return "err:" + value
def tag(var value: String) -> String: return "[" + value + "]"
def tag_twice(var value: String) -> String: return tag(tag(value^))
def id_text(var value: String) -> String: return value^
def recover(var error: String) -> Result[String, String]:
    return Result[String, String](Ok(error^))
def reject(var error: String) -> Result[String, String]:
    return Result[String, String](Err(error^))
def tagged_recovery(var error: String) -> Result[String, String]:
    return reject(error^).or_else(recover)
def result_equal(a: Result[String, String], b: Result[String, String]) raises:
    assert_equal(a.is_ok(), b.is_ok())
    assert_equal(a.fold(show_ok, show_err), b.fold(show_ok, show_err))

def result_laws(value: Int) raises:
    for ok in range(2):
        var r = Result[String, String](Ok(String(value))) if ok else Result[String, String](Err(String(value)))
        result_equal(map[ResultFamily[String]](id_text, r.copy()), r)
        result_equal(map[ResultFamily[String]](tag, map[ResultFamily[String]](tag, r.copy())), map[ResultFamily[String]](tag_twice, r.copy()))
        result_equal(r.copy().map_err(id_text), r)
        result_equal(r.copy().map_err(tag).map_err(tag), r.copy().map_err(tag_twice))
        result_equal(r.copy().or_else(reject), r)
        result_equal(r.copy().or_else(reject).or_else(recover), r.copy().or_else(tagged_recovery))

def effects() raises:
    # Stateful callbacks are tested for order, not assumed pure for fusion laws.
    var trace = ArcPointer(String())
    def first(var value: Int) {trace} -> Int:
        trace[] += "a"
        return value + 1
    def second(var value: Int) {trace} -> Int:
        trace[] += "b"
        return value * 3
    var a = as_unary(first^)
    var b = as_unary(second^)
    comptime Path = TypeList.of[Trait=Movable & Deinitable, Int, Int]()
    assert_equal(pipe[Path](4, a, b), 15)
    assert_equal(trace[], "ab")
    trace[] = ""
    var failed = Result[Int, String](Err(String("domain")))
    _ = map[ResultFamily[type_of(failed).Error]](a, failed^)
    assert_equal(trace[], "")

def main() raises:
    for value in range(-32, 33):
        pipeline(value)
        optional_laws(value)
        result_laws(value)
    effects()
