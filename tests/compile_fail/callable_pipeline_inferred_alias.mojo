# error: aliasing values passed mutably
from fp.functions import pipe, as_unary
def main():
    var calls = 0
    def count(var value: Int) {mut calls} -> Int:
        calls += 1
        return value + calls
    var a = as_unary(count)
    _ = pipe(1, a, a)
