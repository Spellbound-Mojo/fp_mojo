# error: no matching
from fp.functions import pipeline
def factory() -> Int: return 7
def main():
    _ = pipeline(List[Int]([1])).get_or_else(factory)
