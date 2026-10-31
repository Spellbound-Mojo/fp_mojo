"""Generic forwarding preserves both native callback signatures and errors."""
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from std.testing import assert_equal


def rsg_recover[T: Movable & Deinitable, E: Movable & Deinitable, X: Movable & Deinitable,
                F: def(E) raises X -> Bool, G: def(var E) raises X -> T](
    var value: Result[T, E], predicate: F, recover: G
) raises X -> Result[T, E]:
    return value^.recover_if[X=X, Y=X](predicate, recover)


def rsg_continue[T: Movable & Deinitable, E: Movable & Deinitable, X: Movable & Deinitable,
                 F: def(E) raises X -> Bool, G: def(var E) raises X -> Result[T, E]](
    var value: Result[T, E], predicate: F, recover: G
) raises X -> Result[T, E]:
    return pipeline(value^).raising[X]().or_else_if(predicate, recover).get()


def rsg_tap[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable,
            X: Movable & Deinitable, F: def(E) raises X -> Result[U, E]](
    var value: Result[T, E], inspect: F
) raises X -> Result[T, E]:
    return pipeline(value^).raising[X]().flat_tap_err(inspect).get()


def rsg_pure_predicate[T: Movable & Deinitable, E: Movable & Deinitable, X: Movable & Deinitable,
                       F: def(E) -> Bool, G: def(var E) raises X -> T](
    var value: Result[T, E], predicate: F, recover: G
) raises X -> Result[T, E]:
    return pipeline(value^).raising[X]().recover_if(predicate, recover).get()


def rsg_pure_recovery[T: Movable & Deinitable, E: Movable & Deinitable, X: Movable & Deinitable,
                      F: def(E) raises X -> Bool, G: def(var E) -> T](
    var value: Result[T, E], predicate: F, recover: G
) raises X -> Result[T, E]:
    return pipeline(value^).raising[X]().recover_if(predicate, recover).get()


def rsg_predicate(error: String) raises String -> Bool: return error == "retry"
def rsg_pure(error: String) -> Bool: return error == "retry"
def rsg_restore(var error: String) raises String -> Int: return error.byte_length()
def rsg_restore_pure(var error: String) -> Int: return error.byte_length()
def rsg_retry(var error: String) raises String -> Result[Int, String]: return Ok(42)
def rsg_inspect(error: String) raises String -> Result[Int, String]: return Ok(0)


def main() raises:
    var observed = rsg_tap(Result[Int, String](Err(String("retry"))), rsg_inspect)
    assert_equal(rsg_recover(observed^, rsg_predicate, rsg_restore).raise_on_err(), 5)
    var retried = rsg_continue(Result[Int, String](Err(String("retry"))), rsg_predicate, rsg_retry)
    assert_equal(retried^.raise_on_err(), 42)
    var restored = rsg_pure_predicate(Result[Int, String](Err(String("retry"))), rsg_pure, rsg_restore)
    assert_equal(restored^.raise_on_err(), 5)
    var restored_pure = rsg_pure_recovery(Result[Int, String](Err(String("retry"))), rsg_predicate, rsg_restore_pure)
    assert_equal(restored_pure^.raise_on_err(), 5)
