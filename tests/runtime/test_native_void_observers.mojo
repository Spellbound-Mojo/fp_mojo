"""Implicit no-value observers preserve selection and their native error type."""
from fp.data import Result, Ok, Err
from fp.functions import piped
from std.testing import assert_equal, assert_true


@fieldwise_init
struct NativeVoidObserverError(Movable):
    var size: Int


def native_void_never(message: String) raises Never:
    _ = message


def native_void_failure(message: String) raises NativeVoidObserverError:
    raise NativeVoidObserverError(message.byte_length())


def main() raises:
    var calls = 0
    def observe(message: String) {mut calls}:
        calls += message.byte_length()

    var failed = Result[Int, String](Err(String("bad"))).tap_err(observe)
    assert_true(failed.is_err())
    assert_equal(calls, 3)
    var successful = Result[Int, String](Ok(7)).tap_err(observe)
    assert_true(successful.is_ok())
    assert_equal(calls, 3)

    var chained = piped(failed^).tap_err(observe).get()
    assert_true(chained.is_err())
    assert_equal(calls, 6)
    var kept = chained^.tap_err(native_void_never)
    assert_true(kept.is_err())

    var caught = False
    try:
        _ = kept^.tap_err(native_void_failure)
    except error:
        comptime assert type_of(error) == NativeVoidObserverError
        assert_equal(error.size, 3)
        caught = True
    assert_true(caught)
