# error: violated constraint
from fp.functions import pipeline
from fp.effects import IO, ExitCase
from fp.algebra import pure
def cleanup(exit: ExitCase[Int]) -> Int: return 1
def main(): _ = pipeline(pure[IO[Int]](1)).guarantee_case(cleanup)
