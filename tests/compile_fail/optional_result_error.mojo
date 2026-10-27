# error: no matching
from fp.functions import pipeline
from fp.data import Result, Ok
def factory() raises String -> Int: raise String("wrong")
def main():
    _ = pipeline(Optional(1)).raising[Int]().to_result(factory)
