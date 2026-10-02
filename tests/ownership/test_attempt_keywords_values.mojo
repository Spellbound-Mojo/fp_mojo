"""Owned keyword dictionaries transfer move-only values and retain scoped native views."""
from fp.data import attempt, raise_on_err
from std.collections import StringDict
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct AttemptKeywordsValuesToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct AttemptKeywordsValuesFailure(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def transfer(library: Bool, drops: ArcPointer[Int], errors: ArcPointer[Int], calls: ArcPointer[Int]) raises:
    def target(var **values: AttemptKeywordsValuesToken) raises AttemptKeywordsValuesFailure {errors, calls} -> AttemptKeywordsValuesToken:
        calls[] += 1
        try: return values.pop("selected")
        except: raise AttemptKeywordsValuesFailure(17, errors)
    for success in range(2):
        var values = StringDict[AttemptKeywordsValuesToken]()
        values["discarded"] = AttemptKeywordsValuesToken(3, drops)
        if success: values["selected"] = AttemptKeywordsValuesToken(7, drops)
        var code = 0
        var observed = -1
        if library:
            var result = attempt(target, **values^)
            try:
                var token = raise_on_err(result^)
                observed = token.value
            except error: code = error.code
        else:
            try:
                var token = target(**values^)
                observed = token.value
            except error: code = error.code
        assert_equal(code, 0 if success else 17)
        assert_equal(observed, 7 if success else -1)
    assert_equal(calls[], 2)

def views(owner: List[Int]) raises:
    var first = Span(owner)
    comptime View = type_of(first)
    def sum(prefix: List[Int], /, var **values: View) -> Int:
        var total = prefix[0]
        for entry in values.items():
            for value in entry.value: total += value
        return total
    assert_equal(raise_on_err(attempt(sum, owner, first=first, second=Span(owner))), 13)
    assert_equal(sum(owner, first=first, second=Span(owner)), 13)
    var values = StringDict[View]()
    values["view"] = first
    assert_equal(raise_on_err(attempt(sum, owner, **values^)), 7)
    assert_equal(owner[0], 1)

def main() raises:
    for library in range(2):
        var drops = ArcPointer(0)
        var errors = ArcPointer(0)
        var calls = ArcPointer(0)
        transfer(Bool(library), drops, errors, calls)
        assert_equal(drops[], 3)
        assert_equal(errors[], 1)
        assert_equal(calls[], 2)
    var owner: List[Int] = [1, 2, 3]
    views(owner)
    assert_equal(owner[2], 3)
