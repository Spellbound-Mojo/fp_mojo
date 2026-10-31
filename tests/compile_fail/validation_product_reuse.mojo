from fp.functions import pipeline
# error: use of uninitialized
from fp.data import Result, Ok

def main():
    var first = Result[Int,List[String]](Ok(1))
    _ = pipeline(first^).par_product_n(Tuple()).get()
    _ = pipeline(first^).par_product_n(Tuple()).get()
