# error: invalid call to 'sum': lacking evidence to prove correctness
from fp.functions import pipeline
from fp.data import Result, Ok
def main():
    _ = pipeline(Result[Int, String](Ok(1))).sum().get()
