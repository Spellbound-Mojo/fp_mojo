# error: use of uninitialized value 'callback'
from fp.functions import flow
from fp.iteration import iterated
def add(var first: Int, var second: Int) -> Int: return first + second
def twice(var value: Int) -> Int: return 2 * value
def main():
    var callback = flow(add, twice)
    var pending = iterated(range(2)).map_with_index(callback)
    var moved = callback^
    _ = moved.call(0, 0)
    _ = pending^.collect_list()
