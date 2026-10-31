from fp.functions import pipeline
# error: invalid call to 'product': violated constraint
from fp.data import Result, Ok
def main():
    _ = pipeline(Result[Int, String](Ok(1))).product(Result[Int, Int](Ok(2))).get()
