# error: use of uninitialized value 'callback'
from fp.callables import as_binary
from fp.iteration import iterated
def add(var first: Int, var second: Int) -> Int: return first + second
def main():
    var callback = as_binary(add)
    var pending = iterated(range(2)).zip_with(range(2), callback)
    var original = callback^.into_function()
    _ = original(1, 2)
    _ = pending^.collect_list()
