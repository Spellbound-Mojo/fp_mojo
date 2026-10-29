# error: no matching
from fp.functions import pipeline
from fp.effects import Reader, ask
def bad(value: String) -> Int: return 1
def main(): _ = pipeline(ask[Reader[Int]]()).local(bad)
