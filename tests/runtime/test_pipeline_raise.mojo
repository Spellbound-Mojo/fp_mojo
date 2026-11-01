from fp.data import Result, ok, err
from fp.functions import pipeline
from fp.algebra import IdentityFamily
from std.testing import assert_equal

def raise_result[T: Movable & Deinitable, E: Movable & Deinitable](var value: Result[T, E]) raises E -> T:
    return pipeline(value^).raise_on_err()

def pure_result() -> Int:
    return pipeline(ok[Never](3)).raising[String]().raise_on_err()

def twice(var value: Int) raises String -> Int:
    if value < 0: raise String("native")
    return value * 2

def main() raises:
    assert_equal(pure_result(), 3)
    var success = 0
    var reason = String()
    try:
        success = raise_result(ok[String](7))
        _ = raise_result(err[Int]("stored"))
    except error:
        comptime assert type_of(error) == String
        reason = error^
    assert_equal(success, 7)
    assert_equal(reason, "stored")
    # Stored Result errors are independent of selected callback errors and family.
    try:
        _ = pipeline[IdentityFamily](err[Int]("identity")).raising[Int]().raise_on_err()
    except error:
        comptime assert type_of(error) == String
        reason = error^
    assert_equal(reason, "identity")
    for mode in range(3):
        var value = err[Int]("stored") if mode == 2 else ok[String](-1 if mode else 4)
        var called = 0
        def step(var input: Int) raises String {mut called} -> Int:
            called += 1
            return twice(input)
        var output = 0
        reason = String()
        try: output = pipeline(value^).raising[String]().map(step).raise_on_err()
        except error: reason = error^
        assert_equal(output, 8 if mode == 0 else 0)
        assert_equal(reason, "" if mode == 0 else "native" if mode == 1 else "stored")
        assert_equal(called, 0 if mode == 2 else 1)
