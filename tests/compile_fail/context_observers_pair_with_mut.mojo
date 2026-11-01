# error: no matching method
from fp.functions import pipeline
def callback(mut value: String) raises Int -> Int:
    return 1
def main() raises Int:
    _ = pipeline(List[String](["value"])).raising[Int]().pair_with(callback).get()
