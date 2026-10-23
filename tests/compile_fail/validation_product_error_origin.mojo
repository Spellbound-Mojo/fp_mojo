# error: constraint
from fp.data import Result, Ok

def bad(left: List[Int], right: List[Int]):
    _ = Result[Int,List[Span[Int,origin_of(left)]]](Ok(1)).par_product_n(
        (Result[Int,List[Span[Int,origin_of(right)]]](Ok(2)),))
def main(): bad([1],[2])
