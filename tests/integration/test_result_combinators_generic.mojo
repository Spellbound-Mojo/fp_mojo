"""Generic native forwarding keeps Result payload and native error types."""
from fp.data import Result, Ok, Err
from fp.functions import piped
from std.testing import assert_equal


def rcg_tap[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable,
            F: def(T) raises X -> Result[U, E]](var value: Result[T, E], callback: F) raises X -> Result[T, E]:
    return value^.flat_tap[X=X](callback)


def rcg_pair[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable,
             F: def(T) raises X -> Result[U, E]](var value: Result[T, E], callback: F) raises X -> Result[Tuple[T, U], E]:
    return value^.flat_pair_with[X=X](callback)


def rcg_after[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable,
              F: def() raises X -> Result[U, E]](var value: Result[T, E], callback: F) raises X -> Result[U, E]:
    return value^.followed_by[X=X](callback)


def rcg_before[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable,
               F: def() raises X -> Result[U, E]](var value: Result[T, E], callback: F) raises X -> Result[T, E]:
    return value^.before[X=X](callback)


def rcg_recover[T: Movable & Deinitable, E: Movable & Deinitable, X: Movable & Deinitable,
                F: def(var E) raises X -> T](var value: Result[T, E], callback: F) raises X -> Result[T, E]:
    return piped(value^).recover[A=E, R=T, X=X](callback).get()


def rcg_check[T: Movable & Deinitable, E: Movable & Deinitable, X: Movable & Deinitable,
              F: def(T) raises X -> Bool, G: def(T) raises X -> E](
    var value: Result[T, E], predicate: F, make_error: G
) raises X -> Result[T, E]:
    return value^.ensure[X=X, Y=X](predicate, make_error)


def rcg_observe[T: Movable & Deinitable, E: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable,
                F: def(E) raises X -> R](var value: Result[T, E], callback: F) raises X -> Result[T, E]:
    return value^.tap_err[X=X](callback)


def rcg_projection(value: Int) raises String -> Result[String, String]: return Ok(String(value))
def rcg_factory() raises String -> Result[String, String]: return Ok(String("factory"))
def rcg_restore(var error: String) raises String -> Int: return error.byte_length()
def rcg_predicate(value: Int) raises String -> Bool: return value > 0
def rcg_error(value: Int) raises String -> String: return String(value)
def rcg_inspect(error: String) raises String -> Int: return error.byte_length()


def main() raises:
    var code: String
    try:
        var tap = rcg_tap(Result[Int, String](Ok(7)), rcg_projection)
        var pair = rcg_pair(tap^, rcg_projection)
        var original = rcg_before(Result[Int, String](Ok(8)), rcg_factory)
        var later = rcg_after(original^, rcg_factory)
        var checked = rcg_check(Result[Int, String](Ok(-1)), rcg_predicate, rcg_error)
        var observed = rcg_observe(checked^, rcg_inspect)
        var recovered = rcg_recover(observed^, rcg_restore)
        code = String(pair^.raise_on_err()[0]) + later^.raise_on_err() + String(recovered^.raise_on_err())
    except error:
        code = "unexpected: " + error^
    assert_equal(code, "7factory2")
