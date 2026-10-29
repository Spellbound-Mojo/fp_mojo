# error: does not conform to trait 'ReaderAction'
from fp.functions import pipeline
from fp.effects import IO, State
def main(): _ = pipeline(IO[Int].pure(3)).guarantee(State[Int].pure(4))
