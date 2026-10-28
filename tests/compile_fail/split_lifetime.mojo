# error: use of uninitialized value 'callback'
from fp.functions import split
from fp.iteration import iterated
def increment(value: Int) -> Int: return value + 1
def main():
    var callback = split(increment, increment)
    var source: List[Tuple[Int, Int]] = [(1, 2)]
    var pending = iterated(source^).map(callback)
    _ = callback^.call_once((2, 2))
    _ = pending^.collect_list()
