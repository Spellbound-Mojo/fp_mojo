# error: use of uninitialized value 'callback'
from fp.functions import merge
from fp.iteration import iterated
def increment(value: Int) -> Int: return value + 1
def main():
    var callback = merge(increment, increment)
    var source: List[Int] = [1]
    var pending = iterated(source^).map(callback)
    _ = callback^.call_once(2)
    _ = pending^.collect_list()
