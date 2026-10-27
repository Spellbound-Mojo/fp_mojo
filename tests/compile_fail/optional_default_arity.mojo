# error: no matching
from fp.functions import pipeline
def factory(value: Int) -> Int: return value
def main():
    _ = pipeline(Optional[Int]()).get_or_else(factory)
