# error: filter_map: Optional result required
from fp.functions import pipeline
def expansion_lists(x: Int) -> List[Int]: return [x]
def main():
    _ = pipeline(List[Int]([1, 2])).filter_map(expansion_lists).get()
