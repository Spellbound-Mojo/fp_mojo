# error: no matching method in call to 'for_each'
from fp.iteration import iterated
def sink(var x: Int) -> Int: return x
def main(): iterated(range(3)).for_each(sink)
