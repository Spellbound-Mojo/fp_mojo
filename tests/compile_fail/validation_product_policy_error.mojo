from fp.functions import pipeline
# error: constraint
from fp.algebra import StringMonoid
from fp.data import Result, Ok

def main():
    _ = pipeline(Result[Int,List[String]](Ok(1))).par_product_n[StringMonoid](
        (Result[Int,List[String]](Ok(2)),)).get()
