# error: use of uninitialized value 'predicate'
from fp.functions import partial
from fp.iteration import iterated

def below(limit: Int, value: Int) -> Bool: return value < limit
def main():
    var predicate = partial(below, 2)
    var pending = iterated(range(3)).filter(predicate)
    var moved = predicate^
    _ = moved(4)
    _ = pending^.collect_list()
