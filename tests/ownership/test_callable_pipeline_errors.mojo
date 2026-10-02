"""Inferred errors preserve exact copy/drop counts on success and failure."""
from fp.functions import as_unary, pipe
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct CallablePipelineErrorsCounted(Copyable):
    var value: Int
    var copies: ArcPointer[Int]
    var drops: ArcPointer[Int]
    def __init__(out self, *, copy: Self):
        self.value = copy.value
        self.copies = copy.copies
        self.drops = copy.drops
        self.copies[] += 1
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct CallablePipelineErrorsFailure(Copyable):
    var code: Int
    var copies: ArcPointer[Int]
    var drops: ArcPointer[Int]
    def __init__(out self, *, copy: Self):
        self.code = copy.code
        self.copies = copy.copies
        self.drops = copy.drops
        self.copies[] += 1
    def __deinit__(deinit self): self.drops[] += 1

def number(value: CallablePipelineErrorsCounted) raises Never -> Int: return value.value

def exercise(library: Bool, fail: Bool, copies: ArcPointer[Int], drops: ArcPointer[Int], errors: ArcPointer[Int]) -> Int:
    var state = CallablePipelineErrorsCounted(0, copies, drops)
    def increment(var value: CallablePipelineErrorsCounted) raises CallablePipelineErrorsFailure {var state^, fail, copies, errors} -> CallablePipelineErrorsCounted:
        state.value += 1
        value.value += state.value
        if fail: raise CallablePipelineErrorsFailure(value.value, copies, errors)
        return value^
    var add = as_unary(increment^)
    var finish = as_unary(number)
    try:
        if library: return pipe(CallablePipelineErrorsCounted(7, copies, drops), add, finish)
        return finish(add(CallablePipelineErrorsCounted(7, copies, drops)))
    except error: return -error.code

def main() raises:
    for fail in range(2):
        for library in range(2):
            var copies = ArcPointer(0)
            var drops = ArcPointer(0)
            var errors = ArcPointer(0)
            assert_equal(exercise(Bool(library), Bool(fail), copies, drops, errors), -8 if fail else 8)
            assert_equal(copies[], 0)
            assert_equal(drops[], 2)
            assert_equal(errors[], fail)
