# error: no matching method
from fp.functions import pipeline
from fp.algebra import StringMonoid
def bad(mut value: Int) -> String: return String("x")
def main():
    _ = pipeline(List[Int]([1])).fold_map[StringMonoid](bad).get()
