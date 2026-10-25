# error: no matching method in call to 'fold_left'
from fp.functions import pipeline
def wrong(var a: Int, var b: Int) -> String: return String(a + b)
def main(): _ = pipeline(List[Int]([1, 2])).fold_left(wrong, 0).get()
