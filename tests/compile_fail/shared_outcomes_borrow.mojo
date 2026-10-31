# error: uninitialized
from fp.algebra import ResultFamily
from fp.effects import ReaderT, run
from fp.functions import pipeline
from fp.data import Result, Ok
def main():
    comptime F = ReaderT[ResultFamily[String], Int]
    var text = String("retained")
    def inspect(value: Result[Int, String]) {var text^} -> F.Pure[Int]: return F.pure(text.byte_length())
    var pending = pipeline[F](F.pure(1)).attempt_tap(inspect).get()
    var moved = inspect^
    _ = moved(Result[Int, String](Ok(1)))
    _ = run[F](pending^, 0)
