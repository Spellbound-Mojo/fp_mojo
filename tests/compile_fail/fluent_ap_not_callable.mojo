from fp.functions import pipeline
# error: constraint
from fp.data import Result, Ok
def main():
    _ = pipeline(Result[Int,String](Ok(1))).ap(Result[Int,String](Ok(2))).get()
