# error: no matching method
from fp.callables import as_binary
from fp.iteration import iterated
def join(var first: String, var second: String) -> String: return first + second
def main():
    var callback = as_binary(join)
    _ = iterated(range(2)).zip_with(range(2), callback)
