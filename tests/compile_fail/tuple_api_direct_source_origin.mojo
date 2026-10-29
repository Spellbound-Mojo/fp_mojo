# error: cannot implicitly convert
from fp.data import Result, Ok, Err

def wrong(mut owner: List[Int]) -> Result[Tuple[Span[Int, origin_of(owner)], Int], Int]:
    var local: List[Int] = [1]
    return Result[Span[Int, origin_of(local)], Int](Ok(Span(local))).tuple_right(7)

def main():
    var owner: List[Int] = [2]
    _ = wrong(owner)
