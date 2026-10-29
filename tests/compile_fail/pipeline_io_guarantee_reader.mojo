# error: constraint
from fp.functions import pipeline
from fp.effects import IO, Reader
def main(): _ = pipeline(IO[Int].pure(3)).guarantee(Reader[Int].pure(4))
