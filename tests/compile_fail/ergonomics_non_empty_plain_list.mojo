# error: no matching
from fp.iteration import reduce_non_empty
def plus(var a: Int, var b: Int) -> Int: return a + b
def main(): _ = reduce_non_empty(plus, [1,2])
