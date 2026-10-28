# error: use of uninitialized value 'callback'
from fp.callables import as_binary
def add(var first: Int, var second: Int) -> Int: return first + second
def main():
    var callback = as_binary(add)
    var original = callback^.into_function()
    _ = callback(1, 2)
    _ = original(1, 2)
