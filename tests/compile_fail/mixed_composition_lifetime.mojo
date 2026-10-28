# error: use of uninitialized value 'chain'
from fp.functions import flow, partial
from fp.iteration import iterated
def native(var first: Int, var second: Int) -> Int: return first + second
def plus(bias: Int, value: Int) -> Int: return bias + value
def main():
    var chain = flow(native, partial(plus, 1))
    var pending = iterated(range(3)).scan_left(chain, 0)
    var moved = chain^
    _ = moved(0, 0)
    _ = pending^.collect_list()
