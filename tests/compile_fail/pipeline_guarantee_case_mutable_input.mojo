# error: no matching
from fp.functions import pipeline
from fp.effects import IO, ExitCase
from fp.algebra import pure
def cleanup(mut exit: ExitCase[Int]) -> IO[Int].Pure[Int]: return pure[IO[Int]](1)
def main(): _ = pipeline(pure[IO[Int]](1)).guarantee_case(cleanup)
