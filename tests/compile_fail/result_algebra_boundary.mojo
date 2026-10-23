# error: value has no attribute 'product'
from fp.data import Result, Ok
def main():
    _ = Result[Int, String](Ok(1)).product(Result[Int, String](Ok(2)))
