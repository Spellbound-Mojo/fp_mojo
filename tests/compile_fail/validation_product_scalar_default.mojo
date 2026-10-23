# error: no matching
from fp.data import Result, Ok

def main():
    _ = Result[Int,String](Ok(1)).par_product_n((Result[Int,String](Ok(2)),))
