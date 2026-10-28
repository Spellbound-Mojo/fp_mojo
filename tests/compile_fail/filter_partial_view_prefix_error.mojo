# error: no matching method
from fp.functions import partial
from fp.iteration import iterated

def fail(offset: Int, value: Int) raises Int -> Bool: raise offset + value
def main():
    var predicate = partial(fail, 2)
    _ = iterated(range(3)).take_while(predicate)
