# error: no matching method in call to 'partition'
from fp.iteration import iterated, Unbounded
def i3_predicate(value: Int) raises -> Bool: return value > 0
def main(): _ = iterated(range(3)).partition(i3_predicate, buffer=Unbounded())
