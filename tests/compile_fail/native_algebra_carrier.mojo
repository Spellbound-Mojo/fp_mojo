# error: no matching function
# error: MapCompatible
from fp.algebra import map, OptionalFamily

def twice(value: Int) -> Int:
    return value * 2

def main() raises:
    var values: List[Int] = [1, 2]
    _ = map[OptionalFamily](twice, values^)
