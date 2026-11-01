# error: use of uninitialized value 'callback'
from fp.functions import tupled
from fp.iteration import iterated
def add(first: Int, second: Int) -> Int: return first + second
def main():
    var callback = tupled(add)
    var pairs: List[Tuple[Int, Int]] = [(1, 2)]
    var pending = iterated(pairs^).map(callback)
    _ = callback^.call_once((3, 4))
    _ = pending^.collect_list()
