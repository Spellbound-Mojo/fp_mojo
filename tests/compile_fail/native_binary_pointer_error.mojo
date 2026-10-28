# error: no matching method
from fp.callables import as_binary
from fp.iteration import iterated
def fail(var first: Int, var second: Int) raises Int -> Int: raise first + second
def main():
    var callback = as_binary(fail)
    _ = iterated(range(2)).zip_with(range(2), callback)
