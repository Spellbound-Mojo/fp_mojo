# error: no matching method in call to 'map_with_index'
from fp.iteration import iterated
def combine(var a: Int,var b: Int) raises -> Int: return a+b
def main(): _ = iterated(range(3)).map_with_index(combine)
