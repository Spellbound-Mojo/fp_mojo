# error: uninitialized
from fp.functions import as_unary
from fp.iteration import iterated

def double(var value: Int) -> Int: return value * 2
def main():
    var callback = as_unary(double)
    var pending = iterated(List[Int]([1, 2])).map(callback)
    var moved = callback^
    _ = moved(2)
    _ = pending^.collect_list()
