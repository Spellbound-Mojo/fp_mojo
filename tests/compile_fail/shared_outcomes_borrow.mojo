# error: uninitialized
from fp.algebra import ResultFamily
from fp.effects import ReaderT, run
from fp.functions import piped
from fp.data import Result, Ok
def main():
    comptime F = ReaderT[ResultFamily[String], Int]
    var text = String("retained")
    def inspect(value: Result[Int, String]) {var text^} -> F.Pure[Int]: return F.pure(text.byte_length())
    var pending = piped(F.pure(1)).attempt_tap[F](inspect).get()
    var moved = inspect^
    _ = moved(Result[Int, String](Ok(1)))
    _ = run[F](pending^, 0)
