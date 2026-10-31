from fp.functions import pipeline
# error: invalid call to 'par_product_n': lacking evidence
from fp.data import Result, Ok

def main():
    _ = pipeline(Result[Int,String](Ok(1))).par_product_n((Result[Int,String](Ok(2)),)).get()
