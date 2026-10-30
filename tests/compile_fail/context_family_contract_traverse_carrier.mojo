# error: no matching function in call to 'traverse'
from fp.algebra import traverse, ListFamily, ResultFamily
def next(var value: Int) -> Int: return value + 1
def main(): _ = traverse[ListFamily, ResultFamily[String]](List[Int]([1]), next)
