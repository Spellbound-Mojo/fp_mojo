"""Lazy prefixes and indexed mapping, followed by explicit consuming terminals."""
from fp.iteration import iterated
from fp.functions import partial
from fp.algebra import StringMonoid


def selected(var value: Int) -> Optional[String]:
    if value % 2 == 0: return Optional(String(value))
    return None


def below(limit: Int, value: Int) -> Bool: return value < limit

def main():
    var calls = 0
    def prefix(value: Int) {mut calls} -> Bool:
        calls += 1
        return value < 3
    def indexed(var index: Int, var value: Int) -> Int:
        return 10 * index + value
    var stream = iterated(range(8)).drop_while(prefix).take(2).map_with_index(indexed, start=1)
    print("before consuming:", calls)
    var values = stream^.to_list()
    print("values:", values, "; predicate calls:", calls)
    var zipped = iterated(range(2)).zip(range(10,12), range(20,22)).to_list()
    print("zip:", zipped)
    print("selected fold:", iterated(range(6)).collect_fold[M=StringMonoid](selected))
    var present = iterated(range(3)).to_non_empty_list()
    print("non-empty:", len(present.value()), "; empty first:", Bool(iterated(range(0)).first()))
    var under_three = partial(below, 3)
    print("under three:", iterated(range(5)).filter(under_three).collect_list())
    print("suffix:", iterated(range(5)).drop_while(under_three).collect_list())
