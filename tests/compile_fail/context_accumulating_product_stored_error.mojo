# error: no matching method
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from fp.algebra import StringMonoid
def main(): _ = pipeline(Result[Int,List[String]](Ok(1))).par_product_n((Result[Int,String](Ok(2)),)).get()
