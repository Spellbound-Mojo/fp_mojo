from fp.algebra import ErrorRecovery, AttemptContract, ResultFamily, IdentityFamily
from fp.effects import Reader, ResultT, run
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.testing import assert_equal


def materialize[I: ErrorRecovery, V: Movable & Deinitable](var source: V) raises AttemptContract[I, V].Error -> AttemptContract[I, V].Out where AttemptContract[I, V].Compatible:
    return pipeline[I](source^).attempt().get()


def change(var error: String) -> Result[Int, Int]:
    return Ok(error.byte_length())


def main() raises:
    var success = materialize[ResultFamily[String]](Result[Int, String](Ok(42)))
    assert_equal(success^._take_ok()._take_ok(), 42)
    var failure = materialize[ResultFamily[String]](Result[Int, String](Err(String("stored"))))
    assert_equal(failure^._take_ok()._take_err(), "stored")
    comptime R = Reader[Int]
    comptime I = ResultT[R, String]
    var deferred = materialize[I](I.fail[Int](String("deferred")))
    assert_equal(run[R](deferred^, 0)._take_ok()._take_err(), "deferred")
    var changed = pipeline(Result[Int, String](Err(String("four")))).handle_error_with(change).get()
    assert_equal(changed^._take_ok(), 4)
    var intrinsic = pipeline[IdentityFamily](Result[Int, String](Err(String("three")))).handle_error_with(change).get()
    assert_equal(intrinsic^._take_ok(), 5)
    print("Pipeline recovery: generic materialization, deferred layer, native selected and intrinsic handlers")
