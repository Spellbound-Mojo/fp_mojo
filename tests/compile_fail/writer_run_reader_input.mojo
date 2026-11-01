# error: no matching
from fp.effects import Reader, ask, run
def main(): _ = run[Reader[Int]](ask[Reader[Int]]())
