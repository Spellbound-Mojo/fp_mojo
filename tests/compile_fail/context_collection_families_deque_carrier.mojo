# error: no matching method in call to 'map'
from fp.algebra import DequeFamily
from fp.functions import pipeline
def inc(var value: Int) -> Int: return value + 1
def main():
    _ = pipeline[DequeFamily](List[Int]([1, 2])).map(inc)
