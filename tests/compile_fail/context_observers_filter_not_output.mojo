# error: no matching method
from fp.functions import pipeline
def callback(value: Int) -> Int: return value
def main():
    _ = pipeline(List[Int]([1])).filter_not(callback).get()
