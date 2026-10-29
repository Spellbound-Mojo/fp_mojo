# error: no matching
from fp.functions import pipeline
from fp.effects import IO, ExitCase
from fp.algebra import pure
def cleanup(exit: ExitCase[Int]) -> IO[Int].Pure[Int]: return pure[IO[Int]](1)
def main(): _ = pipeline(1).guarantee_case(cleanup)
