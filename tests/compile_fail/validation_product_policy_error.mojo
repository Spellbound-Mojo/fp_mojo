# error: constraint
from fp.algebra import StringMonoid
from fp.data import Result, Ok

def main():
    _ = Result[Int,List[String]](Ok(1)).par_product_n[StringMonoid](
        (Result[Int,List[String]](Ok(2)),))
