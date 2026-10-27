# error: no matching
from fp.functions import pipeline
def scalar(var value: Int) -> Int: return value
def main():
    _ = pipeline(List[Int]([1])).traverse(scalar)
