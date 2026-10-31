# error: constraint
from fp.data import Result, Ok
from fp.functions import pipeline

def bad(left: List[Int], right: List[Int]):
    _ = pipeline(Result[Int,List[Span[Int,origin_of(left)]]](Ok(1))).par_product_n(
        (Result[Int,List[Span[Int,origin_of(right)]]](Ok(2)),))
def main(): bad([1],[2])
