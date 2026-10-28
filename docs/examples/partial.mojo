"""Bind leading arguments of a native function; bind keywords with a closure."""
from fp.functions import partial, pipeline


def twice(var x: Int) -> Int:
    return x * 2


def scale(factor: Int, x: Int) -> Int:
    return factor * x


def above(limit: Int, value: Int) -> Bool: return value > limit

def main() raises:
    var value = 4
    var doubled = partial(twice, value)
    print(doubled())  # 8
    print(doubled())  # 8
    var triple = partial(scale, 3)
    print(triple(5))  # 15
    print("mapped:", pipeline(Optional(4)).map(triple).get_or(0))
    print("reused:", pipeline(6).then(triple).get())

    var greater_than_two = partial(above, 2)
    print("filtered:", pipeline[Int]([1, 2, 3, 4]).filter(greater_than_two).get())
    print("rejected:", pipeline[Int]([1, 2, 3]).filter_not(greater_than_two).get())

    # Keyword binding is a native closure with a capture list.
    var base = 2
    def basetwo(text: String) raises {base} -> Int:
        return atol(text, base=base)
    print(basetwo("10010"))  # 18
