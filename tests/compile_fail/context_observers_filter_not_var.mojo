# error: no matching method
from fp.functions import pipeline
def callback(var value: String) raises Int -> Bool:
    return True
def main() raises Int:
    _ = pipeline(List[String](["value"])).raising[Int]().filter_not(callback).get()
