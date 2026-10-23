from fp.functions import piped
# error: use of uninitialized
from fp.data import Result, Ok

def main():
    var first = Result[Int,List[String]](Ok(1))
    _ = piped(first^).par_product_n(Tuple()).get()
    _ = piped(first^).par_product_n(Tuple()).get()
