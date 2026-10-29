# error: violated constraint
from fp.functions import pipeline
from fp.effects import IO
def main(): _ = pipeline(IO[Int].pure(3)).on_cancel(IO[String].pure(4))
