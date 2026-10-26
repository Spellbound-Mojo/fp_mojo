# error: no matching method
from fp.functions import pipeline
def callback(var value: String) raises Int -> Int:
    return 1
def main() raises Int:
    _ = pipeline(String("value")).raising[Int]().tap(callback).get()
