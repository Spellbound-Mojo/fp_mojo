# error: no matching method
from fp.functions import pipeline
from fp.algebra import StringMonoid
def bad(value: Int) raises Int -> Int: raise 1
def main():
    _ = pipeline(List[Int]([1])).raising[String]().max_by(bad).get()
