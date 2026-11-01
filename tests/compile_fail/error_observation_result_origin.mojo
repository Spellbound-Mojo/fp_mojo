# error: invalid call to 'flat_tap_err': lacking evidence to prove correctness
from fp.data import Result, Err

def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int, origin_of(left)]
    var view = Span(right)
    def inspect(error: L) {view} -> Result[Int, type_of(view)]: return Err(view)
    _ = Result[Int, L](Err(Span(left))).flat_tap_err(inspect)

def main(): bad([1], [2])
