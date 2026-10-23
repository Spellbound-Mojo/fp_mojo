# error: filter_map: Optional result required
from fp.functions import piped
def expansion_lists(x: Int) -> List[Int]: return [x]
def main():
    _ = piped(List[Int]([1, 2])).filter_map(expansion_lists).get()
