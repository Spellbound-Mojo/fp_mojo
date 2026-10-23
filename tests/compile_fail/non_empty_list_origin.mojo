# error: cannot implicitly convert
from fp.data import NonEmptyList

def view(values: List[Int]) -> Span[Int, origin_of(values)]:
    return Span(values)

def escape(anchor: List[Int]) -> NonEmptyList[Span[Int, origin_of(anchor)]]:
    var local = List[Int]([1, 2])
    var borrowed = view(local)
    return NonEmptyList(borrowed)

def main():
    var anchor = List[Int]([3])
    _ = escape(anchor)
