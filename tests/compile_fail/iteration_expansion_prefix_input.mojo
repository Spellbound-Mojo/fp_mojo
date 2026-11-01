# error: no matching method in call to 'drop_while'
from fp.iteration import iterated
def predicate(x: String) -> Bool: return Bool(x)
def main(): _ = iterated(range(3)).drop_while(predicate)
