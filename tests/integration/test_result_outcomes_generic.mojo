"""Generic Result outcome methods keep native payloads and raised errors."""
from fp.data import Result, Ok, Err
from fp.functions import piped
from std.testing import assert_equal


def rog_map[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable,
            V: Movable & Deinitable, X: Movable & Deinitable,
            F: def(var T) raises X -> U, G: def(var E) raises X -> V](
    var source: Result[T, E], on_ok: F, on_err: G
) raises X -> Result[U, V]:
    return source^.map_both[X=X, Y=X](on_ok, on_err)


def rog_redeem[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable,
               X: Movable & Deinitable, F: def(var T) raises X -> U, G: def(var E) -> U](
    var source: Result[T, E], on_ok: F, on_err: G
) raises X -> Result[U, E]:
    return piped(source^).redeem[T=T, Failure=E, X=X](on_ok, on_err).get()


def rog_redeem_right[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable,
                     X: Movable & Deinitable, F: def(var T) -> U, G: def(var E) raises X -> U](
    var source: Result[T, E], on_ok: F, on_err: G
) raises X -> Result[U, E]:
    return source^.redeem[Y=X](on_ok, on_err)


def rog_with[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable,
             V: Movable & Deinitable, X: Movable & Deinitable,
             F: def(var T) raises X -> Result[U, V], G: def(var E) raises X -> Result[U, V]](
    var source: Result[T, E], on_ok: F, on_err: G
) raises X -> Result[U, V]:
    return piped(source^).redeem_with[T=T, Failure=E, U=U, V=V, X=X, Y=X](on_ok, on_err).get()


def rog_tap[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable,
            X: Movable & Deinitable, F: def(Result[T, E]) raises X -> Result[U, E]](
    var source: Result[T, E], inspect: F
) raises X -> Result[T, E]:
    return piped(source^).attempt_tap[T=T, Failure=E, X=X](inspect).get()


def rog_ok(value: Int) raises String -> String: return String(value)
def rog_error(var value: String) raises String -> Int: return value.byte_length()
def rog_recover(var value: String) -> String: return "recovered " + value
def rog_pure(value: Int) -> String: return String(value)
def rog_raise_recover(var value: String) raises String -> String: return "raised " + value
def rog_next(value: Int) raises String -> Result[String, Int]: return Ok(String(value))
def rog_retry(var value: String) raises String -> Result[String, Int]: return Err(value.byte_length())
def rog_observe(value: Result[Int, String]) raises String -> Result[Int, String]: return Ok(0)
def rog_read(var value: String) -> String: return value^
def rog_number(value: Int) -> String: return String(value)


def main() raises:
    var mapped = rog_map(Result[Int, String](Err(String("missing"))), rog_ok, rog_error)
    assert_equal(mapped^.fold_owned(rog_read, rog_number), "7")
    var recovered = rog_redeem(Result[Int, String](Err(String("missing"))), rog_ok, rog_recover)
    assert_equal(recovered^.raise_on_err(), "recovered missing")
    var right = rog_redeem_right(Result[Int, String](Err(String("missing"))), rog_pure, rog_raise_recover)
    assert_equal(right^.raise_on_err(), "raised missing")
    var continued = rog_with(Result[Int, String](Ok(9)), rog_next, rog_retry)
    assert_equal(continued^.fold_owned(rog_read, rog_number), "9")
    var observed = rog_tap(Result[Int, String](Err(String("missing"))), rog_observe)
    assert_equal(observed^.fold_owned(rog_number, rog_read), "missing")
