"""Direct controls for operations previously covered only by family integration."""
from fp.data import Ok, Err, Result, attempt, raise_on_err
from fp.iteration import reduce_optional
from fp.functions import pipe
from std.testing import assert_equal


def main() raises:
    assert_equal(Ok(String("ok")).into_payload(), "ok")
    assert_equal(Err(String("err")).into_payload(), "err")

    var success = Result[Int, Int](Ok(47))
    var failure = Result[Int, Int](Err(53))
    assert_equal(success.is_ok(), True)
    assert_equal(success.is_err(), False)
    assert_equal(failure.is_ok(), False)
    assert_equal(failure.is_err(), True)
    check_error_only_folds()
    check_optional_reduction()
    var captured = attempt(raising_thunk)
    var caught = False
    try:
        _ = raise_on_err(captured^)
    except error:
        comptime assert type_of(error) == Int
        assert_equal(error, 31)
        caught = True
    assert_equal(caught, True)
    caught = False
    try:
        _ = pipe(37, take_error)
    except error:
        comptime assert type_of(error) == Int
        assert_equal(error, 137)
        caught = True
    assert_equal(caught, True)


def read(value: Int) -> Int:
    return value


def take(var value: Int) -> Int:
    return value


def read_error(value: Int) raises Int -> Int:
    raise value + 100


def take_error(var value: Int) raises Int -> Int:
    raise value + 100


def check_error_only_folds() raises:
    for ok in range(2):
        var value = Result[Int, Int](Ok(17)) if ok else Result[Int, Int](Err(19))
        var observed: Int
        try:
            observed = value.fold(read, read_error)
        except error:
            comptime assert type_of(error) == Int
            observed = -error
        assert_equal(observed, 17 if ok else -119)
        try:
            observed = value^.fold_owned(take, take_error)
        except error:
            comptime assert type_of(error) == Int
            observed = -error
        assert_equal(observed, 17 if ok else -119)


def subtract(var total: Int, var item: Int) raises Int -> Int:
    if item < 0:
        raise item
    return total - item


def check_optional_reduction() raises:
    for length in range(4):
        var values = List[Int]()
        for i in range(length):
            values.append(5 - i)
        var actual = reduce_optional(subtract, iter(values^))
        assert_equal(Bool(actual), length != 0)
        if actual:
            assert_equal(actual.value(), 5 if length == 1 else 1 if length == 2 else -2)
    var failing: List[Int] = [5, -7, 3]
    var observed = 0
    try:
        _ = reduce_optional(subtract, iter(failing^))
    except error:
        comptime assert type_of(error) == Int
        observed = error
    assert_equal(observed, -7)


def raising_thunk() raises Int -> Int:
    raise 31
