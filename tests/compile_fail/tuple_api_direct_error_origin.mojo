# error: cannot implicitly convert
from fp.data import Result, Ok, Err

def wrong(mut owner: List[Int]) -> Result[Tuple[Int, Int], Span[Int, origin_of(owner)]]:
    var local: List[Int] = [1]
    return Result[Int, Span[Int, origin_of(local)]](Err(Span(local))).tuple_right(7)

def main():
    var owner: List[Int] = [2]
    _ = wrong(owner)
