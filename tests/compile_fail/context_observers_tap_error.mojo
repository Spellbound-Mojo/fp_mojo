# error: no matching method
from fp.functions import pipeline
def callback(value: String) raises String -> Int: raise String("wrong")
def main() raises Int: _ = pipeline(String("value")).raising[Int]().tap(callback).get()
