# error: cannot implicitly convert
from fp.functions import pipeline
from fp.effects import Reader, ResultT, run
comptime R = Reader[Int]
def twice(var value: Int) -> Int: return value * 2

def external(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    return run[R](pipeline(R.pure(Span(owner))).get(), 0)
def wrong(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    var local: List[Int] = [1]
    return external(local)
def main():
    var owner: List[Int] = [2]
    _ = wrong(owner)
