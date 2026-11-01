# error: cannot implicitly convert
from fp.data import Result, Ok, Err
from fp.algebra import ResultFamily
from algebra_support.tuple_contracts import attached_left, attached_right

def wrong(mut owner: List[Int]) -> Result[Tuple[Span[Int, origin_of(owner)], Int], Int]:
    var local: List[Int] = [1]
    return attached_left[ResultFamily[Int]](Result[Int, Int](Ok(1)), Span(local))

def main():
    var owner: List[Int] = [2]
    _ = wrong(owner)
