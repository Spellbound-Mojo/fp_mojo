# error: cannot implicitly convert
from fp.data import Result, Ok, Err

def wrong(mut owner: List[Int]) -> Result[Tuple[Span[Int, origin_of(owner)], Int], Int]:
    var local: List[Int] = [1]
    return Result[Int, Int](Ok(1)).tuple_left(Span(local))

def main():
    var owner: List[Int] = [2]
    _ = wrong(owner)
