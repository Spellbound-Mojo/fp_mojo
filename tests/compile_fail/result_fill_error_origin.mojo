# error: cannot implicitly convert
from fp.data import Result, Err

def wrong(mut owner: List[Int]) -> Result[Int, Span[Int, origin_of(owner)]]:
    var local: List[Int] = [1]
    return Result[Int, Span[Int, origin_of(local)]](Err(Span(local))).fill(7)

def main():
    var owner: List[Int] = [2]
    _ = wrong(owner)
