# error: no matching method
from fp.functions import pipeline
from fp.algebra import StringMonoid
def bad(var value: Int) raises Int -> String: raise 1
def main():
    _ = pipeline(List[Int]([1])).raising[String]().fold_map[StringMonoid](bad).get()
