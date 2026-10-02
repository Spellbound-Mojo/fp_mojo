"""Bind leading arguments of a native function; bind keywords with a closure."""
from fp.functions import partial


def twice(var x: Int) -> Int:
    return x * 2


def scale(factor: Int, x: Int) -> Int:
    return factor * x


def main() raises:
    var value = 4
    var doubled = partial(twice, value)
    print(doubled())  # 8
    print(doubled())  # 8
    var triple = partial(scale, 3)
    print(triple(5))  # 15

    # Keyword binding is a native closure with a capture list.
    var base = 2
    def basetwo(text: String) raises {base} -> Int:
        return atol(text, base=base)
    print(basetwo("10010"))  # 18
