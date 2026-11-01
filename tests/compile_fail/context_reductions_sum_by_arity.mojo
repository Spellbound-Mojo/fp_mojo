# error: no matching method
from fp.functions import pipeline
from fp.algebra import StringMonoid
def bad() -> Int: return 1
def main():
    _ = pipeline(List[Int]([1])).sum_by(bad).get()
