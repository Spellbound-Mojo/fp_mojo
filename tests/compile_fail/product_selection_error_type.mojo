# error: invalid call to 'product_l': violated constraint
from fp.functions import pipeline
from fp.data import Result, Ok
def main():
    var first: Result[Int,String] = Ok(1)
    var second: Result[Int,Int] = Ok(2)
    _ = pipeline(first^).product_l(second^)
