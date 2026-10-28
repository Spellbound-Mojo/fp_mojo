# error: no matching function
from fp.functions import split
def good(var value: Int) -> Int: return value+1
def main():
    var n=3
    def captured(var a: Int) {n} -> Int: return a+n
    _ = split(captured, good)
