# error: constraint
from fp.data import Result, Ok
def main():
    _ = Result[Int,String](Ok(1)).ap(Result[Int,String](Ok(2)))
