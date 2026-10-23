# error: no matching method in call to 'collect_fold'
from fp.iteration import iterated
from fp.algebra import StringMonoid
def select(var x: Int) -> String: return String(x)
def main(): _ = iterated(range(3)).collect_fold[M=StringMonoid](select)
