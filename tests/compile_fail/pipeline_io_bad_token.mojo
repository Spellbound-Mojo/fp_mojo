# error: no matching
from fp.functions import pipeline
from fp.effects import IO
def main(): _ = pipeline(IO[Int].pure(3)).run_io(String("bad"))
