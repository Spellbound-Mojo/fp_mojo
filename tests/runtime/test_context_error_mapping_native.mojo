"""Result inference keeps positional arguments, exact origins and native errors."""
from fp.functions import pipeline
from fp.algebra import ErrorRecovery, Functor, ApplicativeError, ErrorMapping, ResultFamily, IdentityFamily
from fp.data import Result, Ok, Err
from fp.callables import Unary
from std.testing import assert_equal

from context_error_mapping_support import Show, Size

def generic[A: Movable & Deinitable, E: Movable & Deinitable, B: Movable & Deinitable, G: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A) raises X -> B, H: def(var E) raises X -> G](var source: Result[A,E], f: F, h: H) raises X -> Result[B,G]:
    return pipeline(source^).raising[X]().map_both(f,h).get()

def mixed[A: Movable & Deinitable, E: Movable & Deinitable, B: Movable & Deinitable, G: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A) -> B, H: def(var E) raises X -> G](var source: Result[A,E], f: F, h: H) raises X -> Result[B,G]:
    return pipeline(source^).raising[X]().map_both(f,h).get()

def mixed_reverse[A: Movable & Deinitable, E: Movable & Deinitable, B: Movable & Deinitable, G: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A) raises X -> B, H: def(var E) -> G](var source: Result[A,E], f: F, h: H) raises X -> Result[B,G]:
    return pipeline(source^).raising[X]().map_both(f,h).get()

def generic_error[A: Movable & Deinitable, E: Movable & Deinitable, G: Movable & Deinitable, X: Movable & Deinitable, //, H: def(var E) raises X -> G](var source: Result[A,E], h: H) raises X -> Result[A,G]:
    return pipeline(source^).raising[X]().map_err(h).get()

def intrinsic[A: Movable & Deinitable, E: Movable & Deinitable, G: Movable & Deinitable, X: Movable & Deinitable, //, I: Functor, H: def(var E) raises X -> G](var source: Result[A,E], h: H) raises X -> Result[A,G] where not conforms_to(I,ErrorRecovery) and not conforms_to(I,ErrorMapping):
    return pipeline[I](source^).raising[X]().map_err(h).get()

def origins(left: List[Int], right: List[Int]) raises:
    comptime Left = type_of(Span(left))
    comptime Right = type_of(Span(right))
    def keep(var value: Left) -> Left: return value
    def change(var error: Left) {ref right} -> Right: return Span(right)
    var mapped = pipeline(Result[Left,Left](Err(Span(left)))).map_both(keep,change).get()
    comptime assert type_of(mapped) == Result[Left,Right]
    assert_equal(mapped._err().value.unsafe_ptr() == Span(right).unsafe_ptr(), True)
    var success = pipeline(Result[Left,Left](Ok(Span(left)))).map_err(change).get()
    assert_equal(success._ok().value.unsafe_ptr() == Span(left).unsafe_ptr(), True)
    def raised(var error: Left) raises Right {ref right} -> Int: raise Span(right)
    var same = False
    try: _ = pipeline(Result[Left,Left](Err(Span(left)))).raising[Right]().map_err(raised).get()
    except error:
        comptime assert type_of(error) == Right
        same = error.unsafe_ptr() == Span(right).unsafe_ptr()
    assert_equal(same, True)

def main() raises:
    comptime R = Result[Int,String]
    def show(var value: Int) -> String: return String(value)
    def size(var error: String) -> Int: return error.byte_length()
    var changed = pipeline(R(Err(String("old")))).map_both(show,size)
    comptime assert type_of(changed).I == ResultFamily[Int]
    assert_equal(changed^.get()._err().value,3)
    assert_equal(pipeline(R(Ok(4))).map_both(Show(),size).get()._ok().value,"4")
    assert_equal(pipeline(R(Err(String("five")))).map_both(show,Size()).get()._err().value,4)
    assert_equal(pipeline(R(Err(String("six")))).map_err[Size](Size()).get()._err().value,3)
    assert_equal(pipeline(R(Ok(6))).map_both[Show,Size](Show(),Size()).get()._ok().value,"6")
    assert_equal(pipeline(R(Ok(7))).map_both[String,Int](show,size).get()._ok().value,"7")
    assert_equal(pipeline(R(Err(String("eight")))).map_err[Int](size).get()._err().value,5)
    var pointer: def(var String) thin -> Int = size
    assert_equal(pipeline(R(Err(String("pointer")))).map_err(pointer).get()._err().value,7)
    def raised(var error: String) raises Int -> Int: raise error.byte_length()
    def show_raising(var value: Int) raises Int -> String: return String(value)
    var code = 0
    try: _ = generic(R(Err(String("nine"))), show_raising, raised)
    except error: code = error
    assert_equal(code,4)
    try: _ = mixed(R(Err(String("ten"))), show, raised)
    except error: code = error
    assert_equal(code,3)
    try: _ = generic_error(R(Err(String("eleven"))), raised)
    except error: code = error
    assert_equal(code,6)
    try: _ = intrinsic[IdentityFamily](R(Err(String("twelve"))), raised)
    except error: code = error
    assert_equal(code,6)
    def left_raised(var value: Int) raises Int -> String: raise value
    try: _ = mixed_reverse(R(Ok(9)),left_raised,size)
    except error: code = error
    assert_equal(code,9)
    def show_never(var value: Int) raises Never -> String: return String(value)
    def size_never(var error: String) raises Never -> Int: return error.byte_length()
    assert_equal(generic(R(Ok(10)),show_never,size_never)._ok().value,"10")
    assert_equal(mixed(R(Err(String("same"))),show,size_never)._err().value,4)
    assert_equal(mixed_reverse(R(Ok(11)),show_never,size)._ok().value,"11")
    assert_equal(generic_error(R(Err(String("pure"))),size_never)._err().value,4)
    origins(List[Int]([1]),List[Int]([2]))
