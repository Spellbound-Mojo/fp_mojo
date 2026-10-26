# error: no matching method
from fp.functions import pipeline
def main() raises Int:
    var calls = 0
    def callback(var value: String) raises Int {mut calls} -> Int:
        calls += 1
        return 1
    _ = pipeline(String("value")).raising[Int]().tap(callback).get()
