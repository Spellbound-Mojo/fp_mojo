# error: invalid call to 'product'
from fp.data import Result, Ok
def main():
    _ = Result[Int, String](Ok(1)).product(Result[Int, Int](Ok(2)))
