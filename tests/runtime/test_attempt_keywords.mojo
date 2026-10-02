"""Keyword calls preserve native binding, argument conventions and exact errors."""
from fp.data import Result, attempt, raise_on_err
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
                var captured: Result[String, Never] = attempt(success)
                observed = raise_on_err(captured^)
            else:
                observed = success()
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible()
                except error: code = error.code
    elif count == 1:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, function=3)
                observed = raise_on_err(captured^)
            else:
                observed = success(function=3)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, function=3)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(function=3)
                except error: code = error.code
    elif count == 2:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, function=3, first=5)
                observed = raise_on_err(captured^)
            else:
                observed = success(function=3, first=5)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, function=3, first=5)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(function=3, first=5)
                except error: code = error.code
    elif count == 3:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, function=3, first=5, second=7)
                observed = raise_on_err(captured^)
            else:
                observed = success(function=3, first=5, second=7)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, function=3, first=5, second=7)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(function=3, first=5, second=7)
                except error: code = error.code
    elif count == 4:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, function=3, first=5, second=7, values=11)
                observed = raise_on_err(captured^)
            else:
                observed = success(function=3, first=5, second=7, values=11)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, function=3, first=5, second=7, values=11)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(function=3, first=5, second=7, values=11)
                except error: code = error.code
    elif count == 5:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, function=3, first=5, second=7, values=11, tail=13)
                observed = raise_on_err(captured^)
            else:
                observed = success(function=3, first=5, second=7, values=11, tail=13)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, function=3, first=5, second=7, values=11, tail=13)
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
                var captured: Result[String, Never] = attempt(success, first)
                observed = raise_on_err(captured^)
            else:
                observed = success(first)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first)
                except error: code = error.code
    elif count == 1:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first, function=3)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, function=3)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first, function=3)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, function=3)
                except error: code = error.code
    elif count == 2:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first, function=3, first=5)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, function=3, first=5)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first, function=3, first=5)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, function=3, first=5)
                except error: code = error.code
    elif count == 3:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first, function=3, first=5, second=7)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, function=3, first=5, second=7)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first, function=3, first=5, second=7)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, function=3, first=5, second=7)
                except error: code = error.code
    elif count == 4:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first, function=3, first=5, second=7, values=11)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, function=3, first=5, second=7, values=11)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first, function=3, first=5, second=7, values=11)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, function=3, first=5, second=7, values=11)
                except error: code = error.code
    elif count == 5:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first, function=3, first=5, second=7, values=11, tail=13)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, function=3, first=5, second=7, values=11, tail=13)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first, function=3, first=5, second=7, values=11, tail=13)
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
                var captured: Result[String, Never] = attempt(success, first^)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first^)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^)
                except error: code = error.code
    elif count == 1:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first^, function=3)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, function=3)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first^, function=3)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, function=3)
                except error: code = error.code
    elif count == 2:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first^, function=3, first=5)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, function=3, first=5)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first^, function=3, first=5)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, function=3, first=5)
                except error: code = error.code
    elif count == 3:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first^, function=3, first=5, second=7)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, function=3, first=5, second=7)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first^, function=3, first=5, second=7)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, function=3, first=5, second=7)
                except error: code = error.code
    elif count == 4:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first^, function=3, first=5, second=7, values=11)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, function=3, first=5, second=7, values=11)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first^, function=3, first=5, second=7, values=11)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, function=3, first=5, second=7, values=11)
                except error: code = error.code
    elif count == 5:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first^, function=3, first=5, second=7, values=11, tail=13)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, function=3, first=5, second=7, values=11, tail=13)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first^, function=3, first=5, second=7, values=11, tail=13)
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
                var captured: Result[String, Never] = attempt(success, first, second)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first, second)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second)
                except error: code = error.code
    elif count == 1:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first, second, function=3)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second, function=3)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first, second, function=3)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second, function=3)
                except error: code = error.code
    elif count == 2:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first, second, function=3, first=5)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second, function=3, first=5)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first, second, function=3, first=5)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second, function=3, first=5)
                except error: code = error.code
    elif count == 3:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first, second, function=3, first=5, second=7)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second, function=3, first=5, second=7)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first, second, function=3, first=5, second=7)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second, function=3, first=5, second=7)
                except error: code = error.code
    elif count == 4:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first, second, function=3, first=5, second=7, values=11)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second, function=3, first=5, second=7, values=11)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first, second, function=3, first=5, second=7, values=11)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second, function=3, first=5, second=7, values=11)
                except error: code = error.code
    elif count == 5:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first, second, function=3, first=5, second=7, values=11, tail=13)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second, function=3, first=5, second=7, values=11, tail=13)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first, second, function=3, first=5, second=7, values=11, tail=13)
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
                var captured: Result[String, Never] = attempt(success, first^, second)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first^, second)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second)
                except error: code = error.code
    elif count == 1:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first^, second, function=3)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second, function=3)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first^, second, function=3)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second, function=3)
                except error: code = error.code
    elif count == 2:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first^, second, function=3, first=5)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second, function=3, first=5)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first^, second, function=3, first=5)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second, function=3, first=5)
                except error: code = error.code
    elif count == 3:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first^, second, function=3, first=5, second=7)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second, function=3, first=5, second=7)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first^, second, function=3, first=5, second=7)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second, function=3, first=5, second=7)
                except error: code = error.code
    elif count == 4:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first^, second, function=3, first=5, second=7, values=11)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second, function=3, first=5, second=7, values=11)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first^, second, function=3, first=5, second=7, values=11)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second, function=3, first=5, second=7, values=11)
                except error: code = error.code
    elif count == 5:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first^, second, function=3, first=5, second=7, values=11, tail=13)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second, function=3, first=5, second=7, values=11, tail=13)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first^, second, function=3, first=5, second=7, values=11, tail=13)
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
                var captured: Result[String, Never] = attempt(success, first, second^)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second^)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first, second^)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second^)
                except error: code = error.code
    elif count == 1:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first, second^, function=3)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second^, function=3)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first, second^, function=3)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second^, function=3)
                except error: code = error.code
    elif count == 2:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first, second^, function=3, first=5)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second^, function=3, first=5)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first, second^, function=3, first=5)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second^, function=3, first=5)
                except error: code = error.code
    elif count == 3:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first, second^, function=3, first=5, second=7)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second^, function=3, first=5, second=7)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first, second^, function=3, first=5, second=7)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second^, function=3, first=5, second=7)
                except error: code = error.code
    elif count == 4:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first, second^, function=3, first=5, second=7, values=11)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second^, function=3, first=5, second=7, values=11)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first, second^, function=3, first=5, second=7, values=11)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second^, function=3, first=5, second=7, values=11)
                except error: code = error.code
    elif count == 5:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first, second^, function=3, first=5, second=7, values=11, tail=13)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second^, function=3, first=5, second=7, values=11, tail=13)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first, second^, function=3, first=5, second=7, values=11, tail=13)
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
                var captured: Result[String, Never] = attempt(success, first^, second^)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second^)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first^, second^)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second^)
                except error: code = error.code
    elif count == 1:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first^, second^, function=3)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second^, function=3)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first^, second^, function=3)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second^, function=3)
                except error: code = error.code
    elif count == 2:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first^, second^, function=3, first=5)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second^, function=3, first=5)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first^, second^, function=3, first=5)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second^, function=3, first=5)
                except error: code = error.code
    elif count == 3:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first^, second^, function=3, first=5, second=7)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second^, function=3, first=5, second=7)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first^, second^, function=3, first=5, second=7)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second^, function=3, first=5, second=7)
                except error: code = error.code
    elif count == 4:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first^, second^, function=3, first=5, second=7, values=11)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second^, function=3, first=5, second=7, values=11)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first^, second^, function=3, first=5, second=7, values=11)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second^, function=3, first=5, second=7, values=11)
                except error: code = error.code
    elif count == 5:
        if pure:
            if library:
                var captured: Result[String, Never] = attempt(success, first^, second^, function=3, first=5, second=7, values=11, tail=13)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second^, function=3, first=5, second=7, values=11, tail=13)
        else:
            if library:
                var captured: Result[String, Failure] = attempt(fallible, first^, second^, function=3, first=5, second=7, values=11, tail=13)
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
