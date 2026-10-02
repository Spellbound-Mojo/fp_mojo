"""Generic returns preserve exact cleanup and moves, including discarded Results."""
from fp.data import Result, attempt, raise_on_err
from std.testing import assert_equal

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, var B, /, var **kwargs: K) -> R](
    function: F, mut first: A, var second: B, /, var **values: K
) -> Result[R, Never]:
    return attempt(function, first, second^, **values^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, var B, /, var **kwargs: K) raises X -> R](
    function: F, mut first: A, var second: B, /, var **values: K
) -> Result[R, X]:
    return attempt(function, first, second^, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, var B, /, var **kwargs: K) -> R](
    function: F, mut first: A, var second: B, /, var **values: K
) -> Result[R, Never]:
    return capture(function, first, second^, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, var B, /, var **kwargs: K) raises X -> R](
    function: F, mut first: A, var second: B, /, var **values: K
) -> Result[R, X]:
    return capture(function, first, second^, **values^)

def capture[A: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A) -> R](
    function: F, var first: A
) -> Result[R, Never]:
    return attempt(function, first^)

def capture[A: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A) raises X -> R](
    function: F, var first: A
) -> Result[R, X]:
    return attempt(function, first^)

def forward[A: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A) -> R](
    function: F, var first: A
) -> Result[R, Never]:
    return capture(function, first^)

def forward[A: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A) raises X -> R](
    function: F, var first: A
) -> Result[R, X]:
    return capture(function, first^)

from std.collections import StringDict
from std.memory import ArcPointer

@fieldwise_init
struct Input(Copyable):
    var value: Int
    var drops: ArcPointer[Int]
    var copies: ArcPointer[Int]
    def __init__(out self, *, copy: Self):
        self.value = copy.value
        self.drops = copy.drops
        self.copies = copy.copies
        self.copies[] += 1
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct Item(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct AttemptGenericFailure(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def exercise(library: Bool, pure: Bool, fail: Bool, discard: Bool,
             captures: ArcPointer[Int], copies: ArcPointer[Int]) raises:
    var inputs = ArcPointer(0)
    var arguments = ArcPointer(0)
    var outputs = ArcPointer(0)
    var errors = ArcPointer(0)
    var calls = 0
    var owner = Input(17, captures, copies)
    def success(mut first: Input, var second: Item, /, var **options: Item) {
        imm owner, mut calls, outputs
    } -> Item:
        calls += 1
        first.value += second.value
        var total = owner.value + first.value
        try: total += options["function"].value + options["first"].value
        except: pass
        return Item(total, outputs)
    def fallible(mut first: Input, var second: Item, /, var **options: Item) raises AttemptGenericFailure {
        imm owner, mut calls, outputs, errors, fail
    } -> Item:
        calls += 1
        first.value += second.value
        var total = owner.value + first.value
        try: total += options["function"].value + options["first"].value
        except: pass
        if fail: raise AttemptGenericFailure(total, errors)
        return Item(total, outputs)
    for repetition in range(3):
        var first = Input(3 + repetition, inputs, copies)
        var second = Item(7, arguments)
        var options = StringDict[Item]()
        options["function"] = Item(11, arguments)
        options["first"] = Item(13, arguments)
        var observed = -1
        var code = 0
        if pure:
            if library:
                var result = forward(success, first, second^, **options^)
                assert_equal(outputs[], repetition)
                assert_equal(captures[], 0)
                if not discard:
                    var output = raise_on_err(result^)
                    observed = output.value
            else:
                var output = success(first, second^, **options^)
                if not discard: observed = output.value
        else:
            if library:
                var result: Result[Item, AttemptGenericFailure] = forward(fallible, first, second^, **options^)
                assert_equal(result.is_err(), fail)
                assert_equal(errors[], repetition if fail else 0)
                assert_equal(captures[], 0)
                if not discard:
                    try:
                        var output = raise_on_err(result^)
                        observed = output.value
                    except error: code = error.code
            else:
                try:
                    var output = fallible(first, second^, **options^)
                    if not discard: observed = output.value
                except error:
                    if not discard: code = error.code
        assert_equal(observed, -1 if discard or (fail and not pure) else 51 + repetition)
        assert_equal(code, 51 + repetition if fail and not pure and not discard else 0)
        assert_equal(inputs[], repetition)
        assert_equal(first.value, 10 + repetition)
        assert_equal(arguments[], 3 * (repetition + 1))
        assert_equal(outputs[], 0 if fail and not pure else repetition + 1)
        assert_equal(errors[], repetition + 1 if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(copies[], 0)
    assert_equal(inputs[], 3)
    assert_equal(captures[], 0)
    assert_equal(owner.value, 17)

def transfer(var value: Item) -> Item:
    return value^

def capture_zero[R: Movable & Deinitable, //, F: def() -> R](
    function: F
) -> Result[R, Never]:
    return attempt(function)

def capture_zero[R: Movable & Deinitable, X: Movable & Deinitable, //, F: def() raises X -> R](
    function: F
) -> Result[R, X]:
    return attempt(function)

def forward_zero[R: Movable & Deinitable, //, F: def() -> R](
    function: F
) -> Result[R, Never]:
    return capture_zero(function)

def forward_zero[R: Movable & Deinitable, X: Movable & Deinitable, //, F: def() raises X -> R](
    function: F
) -> Result[R, X]:
    return capture_zero(function)

def moved_capture(drops: ArcPointer[Int]) raises:
    var owner = Item(29, drops)
    var calls = 0
    def read_capture() {var owner^, mut calls} -> Int:
        calls += 1
        return owner.value
    for repetition in range(3):
        var result: Result[Int, Never] = forward_zero(read_capture)
        assert_equal(raise_on_err(result^), 29)
        assert_equal(calls, repetition + 1)
        assert_equal(drops[], 0)

def main() raises:
    var capture_drops = ArcPointer(0)
    moved_capture(capture_drops)
    assert_equal(capture_drops[], 1)
    for library in range(2):
        for pure in range(2):
            for fail in range(2):
                for discard in range(2):
                    var captures = ArcPointer(0)
                    var copies = ArcPointer(0)
                    exercise(Bool(library), Bool(pure), Bool(fail), Bool(discard), captures, copies)
                    assert_equal(captures[], 1)
                    assert_equal(copies[], 0)
    var drops = ArcPointer(0)
    var value = Item(23, drops)
    var result: Result[Item, Never] = forward(transfer, value^)
    assert_equal(drops[], 0)
    var moved_result = result^
    var returned = raise_on_err(moved_result^)
    assert_equal(returned.value, 23)
    assert_equal(drops[], 0)
    _ = returned^
    assert_equal(drops[], 1)
