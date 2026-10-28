# error: cannot implicitly convert
from fp.data import Result, Ok

def wrong(mut owner: List[Int]) -> Result[Span[Int, origin_of(owner)], Int]:
    var local: List[Int] = [1]
    return Result[Int, Int](Ok(1)).fill(Span(local))

def main():
    var owner: List[Int] = [2]
    _ = wrong(owner)
