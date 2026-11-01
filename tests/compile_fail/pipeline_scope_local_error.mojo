# error: no matching
from fp.functions import pipeline
from fp.effects import Reader, ask
def bad(value: Int) raises Int -> Int: raise value
def main() raises: _ = pipeline(ask[Reader[Int]]()).raising[String]().local(bad)
