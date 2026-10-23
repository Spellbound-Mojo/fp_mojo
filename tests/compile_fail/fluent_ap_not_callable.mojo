from fp.functions import piped
# error: constraint
from fp.data import Result, Ok
def main():
    _ = piped(Result[Int,String](Ok(1))).ap(Result[Int,String](Ok(2))).get()
