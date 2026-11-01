# error: no matching method in call to 'zip_with'
from fp.iteration import iterated
def combine(var a: Int,var b: Int) raises -> Int: return a+b
def main(): _ = iterated(range(3)).zip_with(range(3),combine)
