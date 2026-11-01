# error: use of uninitialized value
from fp.functions import pipeline
from fp.effects import IO, ExitCase
from fp.algebra import pure
def cleanup(exit: ExitCase[Int]) -> IO[Int].Pure[Int]: return pure[IO[Int]](1)
def main():
    var value = pipeline(pure[IO[Int]](1))
    _ = value^.guarantee_case(cleanup).run_io()
    _ = value^.run_io()
