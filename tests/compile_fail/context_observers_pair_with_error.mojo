# error: no matching method
from fp.functions import pipeline
def callback(value: String) raises String -> Int: raise String("wrong")
def main() raises Int: _ = pipeline(List[String](["value"])).raising[Int]().pair_with(callback).get()
