# error: violated constraint
from fp.functions import pipeline
from fp.effects import IO, ExitCase
from fp.algebra import pure
def cleanup(exit: ExitCase[Int]) raises String -> IO[Int].Pure[Int]: raise String("bad")
def main(): _ = pipeline(pure[IO[Int]](1)).raising[String]().guarantee_case(cleanup)
