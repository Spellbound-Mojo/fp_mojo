"""Lazy prefixes and indexed mapping, followed by explicit consuming terminals."""
from fp.iteration import iterated
from fp.functions import partial
from fp.algebra import StringMonoid


def selected(divisor: Int, value: Int) -> Optional[String]:
    if value % divisor == 0: return Optional(String(value))
    return None


def below(limit: Int, value: Int) -> Bool: return value < limit

def report(prefix: String, value: Int) -> NoneType:
    print(prefix, value)
    return None

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
    var evens = partial(selected, 2)
    print("selected fold:", iterated(range(6)).collect_fold[M=StringMonoid](evens))
    var present = iterated(range(3)).to_non_empty_list()
    print("non-empty:", len(present.value()), "; empty first:", Bool(iterated(range(0)).first()))
    var under_three = partial(below, 3)
    print("under three:", iterated(range(5)).filter(under_three).collect_list())
    print("suffix:", iterated(range(5)).drop_while(under_three).collect_list())
    print("counted:", iterated(range(5)).count_where(under_three))
    print("selected again:", iterated(range(3)).collect_fold[M=StringMonoid](evens))
    var show = partial(report, String("item:"))
    iterated(range(1)).for_each(show)
    iterated(range(1, 2)).for_each(show)
