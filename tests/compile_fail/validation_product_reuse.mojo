# error: use of uninitialized
from fp.data import Result, Ok

def main():
    var first = Result[Int,List[String]](Ok(1))
    _ = first^.par_product_n(Tuple())
    _ = first^.par_product_n(Tuple())
