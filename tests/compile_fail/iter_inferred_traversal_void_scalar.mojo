# error: no matching
from fp.iteration import iterated
def scalar(var value: Int) -> Int: return value
def main():
    _ = iterated(List[Int]([1])).traverse_void(scalar)
