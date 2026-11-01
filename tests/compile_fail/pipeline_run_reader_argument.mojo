# error: no matching
from fp.functions import pipeline
from fp.effects import Reader
def main(): _ = pipeline(Reader[Int].pure(3)).run(String("bad"))
