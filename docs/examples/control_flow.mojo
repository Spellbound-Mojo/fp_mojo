"""Functional loops over native Mojo values and sequences."""
from fp.control import while_loop, fori_loop, scan


def below_ten(value: Int) -> Bool:
    return value < 10


def double(var value: Int) -> Int:
    return 2 * value


def add_index(var index: Int, var carry: Int) -> Int:
    return carry + index


def running_total(var carry: Int, var value: Int) -> Tuple[Int, Int]:
    var total = carry + value
    return (total, total)


def main() raises:
    print("while:", while_loop(below_ten, double, 1))
    print("fori:", fori_loop(0, 5, add_index, 0))
    var xs: List[Int] = [1, 2, 3]
    var result = scan(running_total, 0, xs^, reverse=True)
    print("scan:", result[0], result[1])
