# error: no matching function in call to 'as_binary'
from fp.callables import as_binary
def add(var first: Int, var second: Int, var third: Int) -> Int: return first + second + third
def main(): _ = as_binary(add)
