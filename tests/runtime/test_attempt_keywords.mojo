"""Keyword calls preserve native binding, argument conventions and exact errors."""
from fp.data import Capture, Result, raise_on_err
from std.testing import assert_equal

@fieldwise_init
struct Token(Movable):
    var value: Int

@fieldwise_init
struct Failure(Movable):
    var code: Int

def exercise_0_0(pure: Bool, library: Bool, negative: Bool, count: Int) raises -> String:
    var calls = 0
    def success(var **values: Int) {mut calls} -> String:
        calls += 1
        var total = 0
        for entry in values.items():
            total += entry.key.byte_length() * entry.value
        return String(7) + ":" + String(total)
    def fallible(var **values: Int) raises Failure {mut calls, negative} -> String:
        calls += 1
        if negative: raise Failure(40 + len(values))
        var total = 0
        for entry in values.items():
            total += entry.key.byte_length() * entry.value
        return String(7) + ":" + String(total)
    var observed = String()
    var code = 0
    if count == 0:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.kwargs[K=Int]().run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success()
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].kwargs[K=Int]().run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible()
                except error: code = error.code
    elif count == 1:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.kwargs(function=3).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(function=3)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].kwargs(function=3).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(function=3)
                except error: code = error.code
    elif count == 2:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.kwargs(function=3, first=5).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(function=3, first=5)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].kwargs(function=3, first=5).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(function=3, first=5)
                except error: code = error.code
    elif count == 3:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.kwargs(function=3, first=5, second=7).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(function=3, first=5, second=7)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].kwargs(function=3, first=5, second=7).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(function=3, first=5, second=7)
                except error: code = error.code
    elif count == 4:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.kwargs(function=3, first=5, second=7, values=11).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(function=3, first=5, second=7, values=11)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].kwargs(function=3, first=5, second=7, values=11).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(function=3, first=5, second=7, values=11)
                except error: code = error.code
    elif count == 5:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.kwargs(function=3, first=5, second=7, values=11, tail=13).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(function=3, first=5, second=7, values=11, tail=13)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].kwargs(function=3, first=5, second=7, values=11, tail=13).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(function=3, first=5, second=7, values=11, tail=13)
                except error: code = error.code
    assert_equal(calls, 1)
    assert_equal(code, 40 + count if negative and not pure else 0)
    return observed^


def exercise_1_0(pure: Bool, library: Bool, negative: Bool, count: Int) raises -> String:
    var calls = 0
    def success(first: Token, /, var **values: Int) {mut calls} -> String:
        calls += 1
        var total = 0
        for entry in values.items():
            total += entry.key.byte_length() * entry.value
        return String(first.value) + ":" + String(total)
    def fallible(first: Token, /, var **values: Int) raises Failure {mut calls, negative} -> String:
        calls += 1
        if negative: raise Failure(40 + len(values))
        var total = 0
        for entry in values.items():
            total += entry.key.byte_length() * entry.value
        return String(first.value) + ":" + String(total)
    var observed = String()
    var code = 0
    var first = Token(7)
    if count == 0:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.borrow(first).kwargs[K=Int]().run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].borrow(first).kwargs[K=Int]().run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first)
                except error: code = error.code
    elif count == 1:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.borrow(first).kwargs(function=3).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, function=3)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].borrow(first).kwargs(function=3).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, function=3)
                except error: code = error.code
    elif count == 2:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.borrow(first).kwargs(function=3, first=5).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, function=3, first=5)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].borrow(first).kwargs(function=3, first=5).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, function=3, first=5)
                except error: code = error.code
    elif count == 3:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.borrow(first).kwargs(function=3, first=5, second=7).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, function=3, first=5, second=7)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].borrow(first).kwargs(function=3, first=5, second=7).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, function=3, first=5, second=7)
                except error: code = error.code
    elif count == 4:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.borrow(first).kwargs(function=3, first=5, second=7, values=11).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, function=3, first=5, second=7, values=11)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].borrow(first).kwargs(function=3, first=5, second=7, values=11).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, function=3, first=5, second=7, values=11)
                except error: code = error.code
    elif count == 5:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.borrow(first).kwargs(function=3, first=5, second=7, values=11, tail=13).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, function=3, first=5, second=7, values=11, tail=13)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].borrow(first).kwargs(function=3, first=5, second=7, values=11, tail=13).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, function=3, first=5, second=7, values=11, tail=13)
                except error: code = error.code
    assert_equal(calls, 1)
    assert_equal(code, 40 + count if negative and not pure else 0)
    assert_equal(first.value, 7)
    return observed^


def exercise_1_1(pure: Bool, library: Bool, negative: Bool, count: Int) raises -> String:
    var calls = 0
    def success(var first: Token, /, var **values: Int) {mut calls} -> String:
        calls += 1
        var total = 0
        for entry in values.items():
            total += entry.key.byte_length() * entry.value
        return String(first.value) + ":" + String(total)
    def fallible(var first: Token, /, var **values: Int) raises Failure {mut calls, negative} -> String:
        calls += 1
        if negative: raise Failure(40 + len(values))
        var total = 0
        for entry in values.items():
            total += entry.key.byte_length() * entry.value
        return String(first.value) + ":" + String(total)
    var observed = String()
    var code = 0
    var first = Token(7)
    if count == 0:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.take(first^).kwargs[K=Int]().run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].take(first^).kwargs[K=Int]().run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^)
                except error: code = error.code
    elif count == 1:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.take(first^).kwargs(function=3).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, function=3)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].take(first^).kwargs(function=3).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, function=3)
                except error: code = error.code
    elif count == 2:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.take(first^).kwargs(function=3, first=5).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, function=3, first=5)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].take(first^).kwargs(function=3, first=5).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, function=3, first=5)
                except error: code = error.code
    elif count == 3:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.take(first^).kwargs(function=3, first=5, second=7).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, function=3, first=5, second=7)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].take(first^).kwargs(function=3, first=5, second=7).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, function=3, first=5, second=7)
                except error: code = error.code
    elif count == 4:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.take(first^).kwargs(function=3, first=5, second=7, values=11).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, function=3, first=5, second=7, values=11)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].take(first^).kwargs(function=3, first=5, second=7, values=11).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, function=3, first=5, second=7, values=11)
                except error: code = error.code
    elif count == 5:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.take(first^).kwargs(function=3, first=5, second=7, values=11, tail=13).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, function=3, first=5, second=7, values=11, tail=13)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].take(first^).kwargs(function=3, first=5, second=7, values=11, tail=13).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, function=3, first=5, second=7, values=11, tail=13)
                except error: code = error.code
    assert_equal(calls, 1)
    assert_equal(code, 40 + count if negative and not pure else 0)
    return observed^


def exercise_2_0(pure: Bool, library: Bool, negative: Bool, count: Int) raises -> String:
    var calls = 0
    def success(first: Token, second: String, /, var **values: Int) {mut calls} -> String:
        calls += 1
        var total = 0
        for entry in values.items():
            total += entry.key.byte_length() * entry.value
        return String(first.value) + second + ":" + String(total)
    def fallible(first: Token, second: String, /, var **values: Int) raises Failure {mut calls, negative} -> String:
        calls += 1
        if negative: raise Failure(40 + len(values))
        var total = 0
        for entry in values.items():
            total += entry.key.byte_length() * entry.value
        return String(first.value) + second + ":" + String(total)
    var observed = String()
    var code = 0
    var first = Token(7)
    var second = String("xy")
    if count == 0:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.borrow(first).borrow(second).kwargs[K=Int]().run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].borrow(first).borrow(second).kwargs[K=Int]().run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second)
                except error: code = error.code
    elif count == 1:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.borrow(first).borrow(second).kwargs(function=3).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second, function=3)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].borrow(first).borrow(second).kwargs(function=3).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second, function=3)
                except error: code = error.code
    elif count == 2:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.borrow(first).borrow(second).kwargs(function=3, first=5).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second, function=3, first=5)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].borrow(first).borrow(second).kwargs(function=3, first=5).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second, function=3, first=5)
                except error: code = error.code
    elif count == 3:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.borrow(first).borrow(second).kwargs(function=3, first=5, second=7).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second, function=3, first=5, second=7)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].borrow(first).borrow(second).kwargs(function=3, first=5, second=7).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second, function=3, first=5, second=7)
                except error: code = error.code
    elif count == 4:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.borrow(first).borrow(second).kwargs(function=3, first=5, second=7, values=11).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second, function=3, first=5, second=7, values=11)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].borrow(first).borrow(second).kwargs(function=3, first=5, second=7, values=11).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second, function=3, first=5, second=7, values=11)
                except error: code = error.code
    elif count == 5:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.borrow(first).borrow(second).kwargs(function=3, first=5, second=7, values=11, tail=13).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second, function=3, first=5, second=7, values=11, tail=13)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].borrow(first).borrow(second).kwargs(function=3, first=5, second=7, values=11, tail=13).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second, function=3, first=5, second=7, values=11, tail=13)
                except error: code = error.code
    assert_equal(calls, 1)
    assert_equal(code, 40 + count if negative and not pure else 0)
    assert_equal(first.value, 7)
    assert_equal(second, "xy")
    return observed^


def exercise_2_1(pure: Bool, library: Bool, negative: Bool, count: Int) raises -> String:
    var calls = 0
    def success(var first: Token, second: String, /, var **values: Int) {mut calls} -> String:
        calls += 1
        var total = 0
        for entry in values.items():
            total += entry.key.byte_length() * entry.value
        return String(first.value) + second + ":" + String(total)
    def fallible(var first: Token, second: String, /, var **values: Int) raises Failure {mut calls, negative} -> String:
        calls += 1
        if negative: raise Failure(40 + len(values))
        var total = 0
        for entry in values.items():
            total += entry.key.byte_length() * entry.value
        return String(first.value) + second + ":" + String(total)
    var observed = String()
    var code = 0
    var first = Token(7)
    var second = String("xy")
    if count == 0:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.take(first^).borrow(second).kwargs[K=Int]().run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].take(first^).borrow(second).kwargs[K=Int]().run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second)
                except error: code = error.code
    elif count == 1:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.take(first^).borrow(second).kwargs(function=3).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second, function=3)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].take(first^).borrow(second).kwargs(function=3).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second, function=3)
                except error: code = error.code
    elif count == 2:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.take(first^).borrow(second).kwargs(function=3, first=5).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second, function=3, first=5)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].take(first^).borrow(second).kwargs(function=3, first=5).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second, function=3, first=5)
                except error: code = error.code
    elif count == 3:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.take(first^).borrow(second).kwargs(function=3, first=5, second=7).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second, function=3, first=5, second=7)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].take(first^).borrow(second).kwargs(function=3, first=5, second=7).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second, function=3, first=5, second=7)
                except error: code = error.code
    elif count == 4:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.take(first^).borrow(second).kwargs(function=3, first=5, second=7, values=11).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second, function=3, first=5, second=7, values=11)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].take(first^).borrow(second).kwargs(function=3, first=5, second=7, values=11).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second, function=3, first=5, second=7, values=11)
                except error: code = error.code
    elif count == 5:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.take(first^).borrow(second).kwargs(function=3, first=5, second=7, values=11, tail=13).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second, function=3, first=5, second=7, values=11, tail=13)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].take(first^).borrow(second).kwargs(function=3, first=5, second=7, values=11, tail=13).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second, function=3, first=5, second=7, values=11, tail=13)
                except error: code = error.code
    assert_equal(calls, 1)
    assert_equal(code, 40 + count if negative and not pure else 0)
    assert_equal(second, "xy")
    return observed^


def exercise_2_2(pure: Bool, library: Bool, negative: Bool, count: Int) raises -> String:
    var calls = 0
    def success(first: Token, var second: String, /, var **values: Int) {mut calls} -> String:
        calls += 1
        var total = 0
        for entry in values.items():
            total += entry.key.byte_length() * entry.value
        return String(first.value) + second + ":" + String(total)
    def fallible(first: Token, var second: String, /, var **values: Int) raises Failure {mut calls, negative} -> String:
        calls += 1
        if negative: raise Failure(40 + len(values))
        var total = 0
        for entry in values.items():
            total += entry.key.byte_length() * entry.value
        return String(first.value) + second + ":" + String(total)
    var observed = String()
    var code = 0
    var first = Token(7)
    var second = String("xy")
    if count == 0:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.borrow(first).take(second^).kwargs[K=Int]().run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second^)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].borrow(first).take(second^).kwargs[K=Int]().run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second^)
                except error: code = error.code
    elif count == 1:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.borrow(first).take(second^).kwargs(function=3).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second^, function=3)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].borrow(first).take(second^).kwargs(function=3).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second^, function=3)
                except error: code = error.code
    elif count == 2:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.borrow(first).take(second^).kwargs(function=3, first=5).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second^, function=3, first=5)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].borrow(first).take(second^).kwargs(function=3, first=5).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second^, function=3, first=5)
                except error: code = error.code
    elif count == 3:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.borrow(first).take(second^).kwargs(function=3, first=5, second=7).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second^, function=3, first=5, second=7)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].borrow(first).take(second^).kwargs(function=3, first=5, second=7).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second^, function=3, first=5, second=7)
                except error: code = error.code
    elif count == 4:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.borrow(first).take(second^).kwargs(function=3, first=5, second=7, values=11).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second^, function=3, first=5, second=7, values=11)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].borrow(first).take(second^).kwargs(function=3, first=5, second=7, values=11).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second^, function=3, first=5, second=7, values=11)
                except error: code = error.code
    elif count == 5:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.borrow(first).take(second^).kwargs(function=3, first=5, second=7, values=11, tail=13).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second^, function=3, first=5, second=7, values=11, tail=13)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].borrow(first).take(second^).kwargs(function=3, first=5, second=7, values=11, tail=13).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second^, function=3, first=5, second=7, values=11, tail=13)
                except error: code = error.code
    assert_equal(calls, 1)
    assert_equal(code, 40 + count if negative and not pure else 0)
    assert_equal(first.value, 7)
    return observed^


def exercise_2_3(pure: Bool, library: Bool, negative: Bool, count: Int) raises -> String:
    var calls = 0
    def success(var first: Token, var second: String, /, var **values: Int) {mut calls} -> String:
        calls += 1
        var total = 0
        for entry in values.items():
            total += entry.key.byte_length() * entry.value
        return String(first.value) + second + ":" + String(total)
    def fallible(var first: Token, var second: String, /, var **values: Int) raises Failure {mut calls, negative} -> String:
        calls += 1
        if negative: raise Failure(40 + len(values))
        var total = 0
        for entry in values.items():
            total += entry.key.byte_length() * entry.value
        return String(first.value) + second + ":" + String(total)
    var observed = String()
    var code = 0
    var first = Token(7)
    var second = String("xy")
    if count == 0:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.take(first^).take(second^).kwargs[K=Int]().run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second^)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].take(first^).take(second^).kwargs[K=Int]().run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second^)
                except error: code = error.code
    elif count == 1:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.take(first^).take(second^).kwargs(function=3).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second^, function=3)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].take(first^).take(second^).kwargs(function=3).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second^, function=3)
                except error: code = error.code
    elif count == 2:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.take(first^).take(second^).kwargs(function=3, first=5).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second^, function=3, first=5)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].take(first^).take(second^).kwargs(function=3, first=5).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second^, function=3, first=5)
                except error: code = error.code
    elif count == 3:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.take(first^).take(second^).kwargs(function=3, first=5, second=7).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second^, function=3, first=5, second=7)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].take(first^).take(second^).kwargs(function=3, first=5, second=7).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second^, function=3, first=5, second=7)
                except error: code = error.code
    elif count == 4:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.take(first^).take(second^).kwargs(function=3, first=5, second=7, values=11).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second^, function=3, first=5, second=7, values=11)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].take(first^).take(second^).kwargs(function=3, first=5, second=7, values=11).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second^, function=3, first=5, second=7, values=11)
                except error: code = error.code
    elif count == 5:
        if pure:
            if library:
                var captured: Result[String, Never] = Capture.take(first^).take(second^).kwargs(function=3, first=5, second=7, values=11, tail=13).run(success)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second^, function=3, first=5, second=7, values=11, tail=13)
        else:
            if library:
                var captured: Result[String, Failure] = Capture[Failure].take(first^).take(second^).kwargs(function=3, first=5, second=7, values=11, tail=13).run(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second^, function=3, first=5, second=7, values=11, tail=13)
                except error: code = error.code
    assert_equal(calls, 1)
    assert_equal(code, 40 + count if negative and not pure else 0)
    return observed^


def main() raises:
    var expected = [0, 24, 49, 91, 157, 209]
    for pure in range(2):
        for negative in range(2):
            for count in range(6):
                var output_0_0 = exercise_0_0(Bool(pure), True, Bool(negative), count)
                assert_equal(output_0_0, exercise_0_0(Bool(pure), False, Bool(negative), count))
                assert_equal(output_0_0, String() if negative and not pure else "7:" + String(expected[count]))
                var output_1_0 = exercise_1_0(Bool(pure), True, Bool(negative), count)
                assert_equal(output_1_0, exercise_1_0(Bool(pure), False, Bool(negative), count))
                assert_equal(output_1_0, String() if negative and not pure else "7:" + String(expected[count]))
                var output_1_1 = exercise_1_1(Bool(pure), True, Bool(negative), count)
                assert_equal(output_1_1, exercise_1_1(Bool(pure), False, Bool(negative), count))
                assert_equal(output_1_1, String() if negative and not pure else "7:" + String(expected[count]))
                var output_2_0 = exercise_2_0(Bool(pure), True, Bool(negative), count)
                assert_equal(output_2_0, exercise_2_0(Bool(pure), False, Bool(negative), count))
                assert_equal(output_2_0, String() if negative and not pure else "7xy:" + String(expected[count]))
                var output_2_1 = exercise_2_1(Bool(pure), True, Bool(negative), count)
                assert_equal(output_2_1, exercise_2_1(Bool(pure), False, Bool(negative), count))
                assert_equal(output_2_1, String() if negative and not pure else "7xy:" + String(expected[count]))
                var output_2_2 = exercise_2_2(Bool(pure), True, Bool(negative), count)
                assert_equal(output_2_2, exercise_2_2(Bool(pure), False, Bool(negative), count))
                assert_equal(output_2_2, String() if negative and not pure else "7xy:" + String(expected[count]))
                var output_2_3 = exercise_2_3(Bool(pure), True, Bool(negative), count)
                assert_equal(output_2_3, exercise_2_3(Bool(pure), False, Bool(negative), count))
                assert_equal(output_2_3, String() if negative and not pure else "7xy:" + String(expected[count]))
