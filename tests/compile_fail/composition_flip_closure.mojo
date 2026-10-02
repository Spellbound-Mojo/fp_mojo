# error: no matching function in call to 'flip'
from fp.functions import flip


def main():
    var k = 1
    def sub(a: Int, b: Int) {imm k} -> Int:
        return a - b - k
    _ = flip(sub)
