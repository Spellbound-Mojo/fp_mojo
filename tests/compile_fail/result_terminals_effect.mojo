# error: cannot call function that may raise
from fp.data import Result, Ok
def fallback() raises String -> Int: raise String("failure")
def main():
    # Even a success value cannot erase the callback's declared native effect.
    _ = Result[Int, String](Ok(1)).get_or_else(fallback)
