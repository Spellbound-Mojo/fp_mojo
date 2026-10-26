# error: aliasing values passed mutably
from fp.functions import pipeline
from fp.effects import Reader, run
def main():
    var calls = 0
    def first(value: Int) {mut calls} -> Int:
        calls += 1
        return value
    def second(value: Int) {mut calls} -> Int:
        calls += 1
        return value
    comptime Deferred = Reader[Int]
    var pending = pipeline[Deferred](Deferred.pure(1)).tap_each(first).pair_with(second).get()
    _ = run[Deferred](pending^,0)
