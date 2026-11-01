# error: cannot implicitly convert
from fp.data import Result, Ok, Err
from fp.algebra import ResultFamily
from algebra_support.tuple_contracts import attached_left, attached_right

def wrong(mut owner: List[Int]) -> Result[Tuple[Int, Int], Span[Int, origin_of(owner)]]:
    var local: List[Int] = [1]
    return attached_right[ResultFamily[Span[Int, origin_of(local)]]](Result[Int, Span[Int, origin_of(local)]](Err(Span(local))), 7)

def main():
    var owner: List[Int] = [2]
    _ = wrong(owner)
