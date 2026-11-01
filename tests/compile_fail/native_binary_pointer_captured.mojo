# error: no matching function in call to 'as_binary'
from fp.callables import as_binary
def main():
    var offset = 3
    def captured(var first: Int, var second: Int) {offset} -> Int: return first + second + offset
    _ = as_binary(captured)
