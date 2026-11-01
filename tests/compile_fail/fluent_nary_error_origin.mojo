from fp.functions import pipeline
# error: constraint
from fp.data import Result,Ok
def bad(left:List[Int],right:List[Int]):
    _=pipeline(Result[Int,Span[Int,origin_of(left)]](Ok(1))).product_n((Result[Int,Span[Int,origin_of(right)]](Ok(2)),)).get()
def main(): bad([1],[2])
