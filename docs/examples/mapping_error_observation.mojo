"""Observe errors in a State action whose state is move-only."""
from fp.algebra import ResultFamily
from fp.data import Result, Err
from fp.effects import StateT, run
from fp.functions import pipeline

@fieldwise_init
struct Session(Movable):
    var requests: Int


def record(error: String):
    print("observed:", error)


def main() raises:
    comptime SessionState = StateT[ResultFamily[String], Session]
    var request = SessionState.lift(Result[Int, String](Err(String("unavailable"))))
    var pending = pipeline[SessionState](request^).tap_err(record).get()
    print("before run")
    var outcome = run[SessionState](pending^, Session(1))
    print("retained:", outcome^.swap().to_optional().value())
