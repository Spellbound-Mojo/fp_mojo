"""Mutable scalar/resource calls, nested errors, keyword ownership and repeated state."""
from fp.data import Result, Ok, Err, attempt, raise_on_err
from std.collections import StringDict
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Token(Movable):
    var value: Int

@fieldwise_init
struct Failure(Movable):
    var code: Int

@fieldwise_init
struct InnerFailure(Movable):
    var code: Int

@fieldwise_init
struct Item(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

comptime Nested = Result[Token, InnerFailure]

def stateful(mut value: Token, fail: Bool) raises Failure -> Nested:
    value.value += 1
    if fail: raise Failure(value.value)
    return Nested(Err(InnerFailure(value.value)))

def keywords(mut value: Token, /, var **options: Int) raises Failure -> Int:
    for entry in options.items(): value.value += entry.value
    if value.value > 10: raise Failure(value.value)
    return value.value

def forward(mut value: Token, /, var **options: Int) -> Result[Int, Failure]:
    return attempt(keywords, value, **options^)

def scalar_left(mut first: Int, second: Int) -> Int:
    first += second
    return first

def scalar_right(first: Int, mut second: Int, /, var **values: Int) raises Failure -> Int:
    second += first
    for entry in values.items(): second += entry.value
    if second > 10: raise Failure(second)
    return second

def scalar_both(mut first: Int, mut second: Int) -> Int:
    first += 3
    second *= 2
    return first + second

def heterogeneous(mut value: Token, text: String, /, var **options: Int) -> Int:
    value.value += text.byte_length()
    for entry in options.items(): value.value += entry.value
    return value.value

def main() raises:
    for library in range(2):
        var value = Token(3)
        for fail in range(2):
            var observed = 0
            var nested: Optional[Nested] = None
            if library:
                var captured: Result[Nested, Failure] = attempt(stateful, value, Bool(fail))
                try: nested = Optional(raise_on_err(captured^))
                except error: observed = error.code
            else:
                try: nested = Optional(stateful(value, Bool(fail)))
                except error: observed = error.code
            assert_equal(value.value, 4 + fail)
            assert_equal(observed, 5 if fail else 0)
            if not fail:
                var inner = nested.take()
                assert_equal(inner.is_err(), True)
                var inner_code = 0
                try: _ = raise_on_err(inner^)
                except error: inner_code = error.code
                assert_equal(inner_code, 4)
        var options = StringDict[Int]()
        options["first"] = 2
        options["function"] = 3
        var code = 0
        var result: Int
        if library:
            try: result = raise_on_err(forward(value, **options^))
            except error: raise Error("unexpected typed failure")
            try: _ = raise_on_err(forward(value, next=4))
            except error: code = error.code
        else:
            try: result = keywords(value, **options^)
            except error: raise Error("unexpected typed failure")
            try: _ = keywords(value, next=4)
            except error: code = error.code
        assert_equal(result, 10)
        assert_equal(value.value, 14)
        assert_equal(code, 14)
        var first = 2
        var second = 3
        var text = String("abc")
        if library:
            assert_equal(raise_on_err(attempt(scalar_left, first, second)), 5)
            var scalar_result: Int
            try: scalar_result = raise_on_err(attempt(scalar_right, first, second, extra=1))
            except error: raise Error("unexpected typed failure")
            assert_equal(scalar_result, 9)
            assert_equal(raise_on_err(attempt(scalar_both, first, second)), 26)
            assert_equal(raise_on_err(attempt(heterogeneous, value, text, more=2)), 19)
        else:
            assert_equal(scalar_left(first, second), 5)
            var scalar_result: Int
            try: scalar_result = scalar_right(first, second, extra=1)
            except error: raise Error("unexpected typed failure")
            assert_equal(scalar_result, 9)
            assert_equal(scalar_both(first, second), 26)
            assert_equal(heterogeneous(value, text, more=2), 19)
        assert_equal(first, 8)
        assert_equal(second, 18)
        assert_equal(text, "abc")
        assert_equal(value.value, 19)
        def stop(mut current: Int) raises StopIteration -> Int:
            current += 1
            raise StopIteration()
        def no_value(mut current: Int, /, var **values: Int):
            current += len(values)
        if library:
            var stopped: Result[Int, StopIteration] = attempt(stop, first)
            assert_equal(stopped.is_err(), True)
            var empty = attempt(no_value, first, a=1, b=2)
            assert_equal(empty.is_ok(), True)
        else:
            try: _ = stop(first)
            except: pass
            no_value(first, a=1, b=2)
        assert_equal(first, 11)

    for library in range(2):
        for fail in range(2):
            var drops = ArcPointer(0)
            var calls = ArcPointer(0)
            var current = Token(0)
            def select(mut value: Token, /, var **items: Item) raises Failure {calls, fail} -> Item:
                calls[] += 1
                value.value += len(items)
                if fail: raise Failure(value.value)
                try: return items.pop("selected")
                except: raise Failure(99)
            var code = 0
            var observed = -1
            if library:
                var captured = attempt(select, current, selected=Item(7, drops), unused=Item(11, drops))
                try:
                    var chosen = raise_on_err(captured^)
                    observed = chosen.value
                except error: code = error.code
            else:
                try:
                    var chosen = select(current, selected=Item(7, drops), unused=Item(11, drops))
                    observed = chosen.value
                except error: code = error.code
            assert_equal(observed, -1 if fail else 7)
            assert_equal(code, 2 if fail else 0)
            assert_equal(current.value, 2)
            assert_equal(calls[], 1)
            assert_equal(drops[], 2)
