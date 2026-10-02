"""Public Result constructor identity, matching, nested folds, and pure specializations."""
import fp
from fp.algebra import map, ResultFamily
from fp.data import Result, Ok, Err
from std.testing import assert_equal

def positive(value: Int) -> Int:
    return value

def negative(value: Int) -> Int:
    return -value

def consume(var value: Int) -> Int:
    return value + 1

def consume_error(var value: Int) -> Int:
    return -value - 1

def text(value: String) -> Int:
    return value.byte_length()

def consume_text(var value: String) -> Int:
    return -value.byte_length()

def inner_value(value: Result[Int, Int]) -> Int:
    return value.fold(positive, negative)

def inner_owned(var value: Result[Int, Int]) -> Int:
    return value^.fold_owned(consume, consume_error)

def never(var value: Int) raises Never -> Int:
    return value * 2

def never_borrow(value: Int) raises Never -> Int:
    return value * 2

def typed_borrow(value: Int) raises Int -> Int:
    return value * 3

def typed_owned(var value: Int) raises Int -> Int:
    return value * 3

def pure(ok: Bool) -> Int:
    var value = Result[Int, Int](Ok(7)) if ok else Result[Int, Int](Err(7))
    _ = value.fold(never_borrow, never_borrow)
    var mapped = map[ResultFamily[type_of(value).Error]](consume, value^)
    var remapped = mapped^.map_err(consume)
    var empty_error = map[ResultFamily[type_of(remapped).Error]](never, remapped^)
    return empty_error^.fold_owned(consume, consume_error)

def main() raises:
    assert_equal(pure(True), 17)
    assert_equal(pure(False), -9)
    var never_pair = Result[Int, Int](Ok(2))
    # Both explicit Never callbacks remain a non-raising specialization.
    _ = never_pair.fold(never_borrow, never_borrow)
    for ok in range(2):
        var value = Result[Int, Int](Ok(7)) if ok else Result[Int, Int](Err(7))
        assert_equal(value.is_ok(), Bool(ok))
        assert_equal(value.is_err(), not Bool(ok))
        # Clauses for different constructors may come in any order.
        assert_equal(fp.match(value, lambda (e: Err[Int]) -> Int: -e.value, lambda (o: Ok[Int]) -> Int: o.value), 7 if ok else -7)
        assert_equal(value.fold(never_borrow, typed_borrow), 14 if ok else 21)
        assert_equal(value.fold(typed_borrow, never_borrow), 21 if ok else 14)
        var never_owned = value.copy()
        assert_equal(never_owned^.fold_owned(never, typed_owned), 14 if ok else 21)
        never_owned = value.copy()
        assert_equal(never_owned^.fold_owned(typed_owned, never), 21 if ok else 14)
        var copied = value.copy()
        assert_equal(copied^.fold_owned(consume, consume_error), 8 if ok else -8)
    for tag in range(3):
        var inner = Result[Int, Int](Ok(9)) if tag == 0 else Result[Int, Int](Err(9))
        var outer = Result[Result[Int, Int], String](Ok(inner^)) if tag < 2 else Result[Result[Int, Int], String](Err(String("bad")))
        assert_equal(outer.fold(inner_value, text), 9 if tag == 0 else -9 if tag == 1 else 3)
        assert_equal(outer^.fold_owned(inner_owned, consume_text), 10 if tag == 0 else -10 if tag == 1 else -3)
