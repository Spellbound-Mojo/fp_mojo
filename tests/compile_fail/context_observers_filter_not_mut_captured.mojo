# error: no matching method
from fp.functions import pipeline
def main() raises Int:
    var calls = 0
    def callback(mut value: String) raises Int {mut calls} -> Bool:
        calls += 1
        return True
    _ = pipeline(List[String](["value"])).raising[Int]().filter_not(callback).get()
