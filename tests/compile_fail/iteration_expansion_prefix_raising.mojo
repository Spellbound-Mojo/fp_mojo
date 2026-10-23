# error: no matching method in call to 'take_while'
from fp.iteration import iterated
def predicate(x: Int) raises -> Bool: return x > 0
def main(): _ = iterated(range(3)).take_while(predicate)
