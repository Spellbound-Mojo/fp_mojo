# error: no matching method
from fp.functions import pipeline
def main():
    var calls = 0
    def callback(value: Int) {mut calls} -> Int:
        calls += 1
        return value
    _ = pipeline(List[Int]([1])).filter_not(callback).get()
