"""Mutable forwarding preserves visible changes before success or typed failure."""
from fp.data import Result, attempt, raise_on_err
from std.testing import assert_equal

@fieldwise_init
struct Token(Movable):
    var value: Int

@fieldwise_init
struct Failure(Movable):
    var code: Int

def exercise_0_0(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(mut first: Token) {mut calls} -> Int:
        calls += 1
        first.value += 10
        var total = 100 * first.value
        return total
    def fallible(mut first: Token) raises Failure {mut calls, fail} -> Int:
        calls += 1
        first.value += 10
        if fail: raise Failure(40 + calls)
        var total = 100 * first.value
        return total
    for repetition in range(2):
        var first = Token(2 + repetition)
        var observed = -1
        var code = 0
        if pure:
            if library:
                var captured: Result[Int, Never] = attempt(success, first)
                observed = raise_on_err(captured^)
            else:
                observed = success(first)
        else:
            if library:
                var captured: Result[Int, Failure] = attempt(fallible, first)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first)
                except error: code = error.code
        assert_equal(calls, repetition + 1)
        assert_equal(code, 41 + repetition if fail and not pure else 0)
        assert_equal(observed, -1 if fail and not pure else 100 * (12 + repetition))
        assert_equal(first.value, 12 + repetition)


def exercise_0_1(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(first: Token, mut second: Token) {mut calls} -> Int:
        calls += 1
        second.value *= 3
        var total = 100 * first.value + second.value
        return total
    def fallible(first: Token, mut second: Token) raises Failure {mut calls, fail} -> Int:
        calls += 1
        second.value *= 3
        if fail: raise Failure(40 + calls)
        var total = 100 * first.value + second.value
        return total
    for repetition in range(2):
        var first = Token(2 + repetition)
        var second = Token(5 + repetition)
        var observed = -1
        var code = 0
        if pure:
            if library:
                var captured: Result[Int, Never] = attempt(success, first, second)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second)
        else:
            if library:
                var captured: Result[Int, Failure] = attempt(fallible, first, second)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second)
                except error: code = error.code
        assert_equal(calls, repetition + 1)
        assert_equal(code, 41 + repetition if fail and not pure else 0)
        assert_equal(observed, -1 if fail and not pure else 100 * (2 + repetition) + 3 * (5 + repetition))
        assert_equal(first.value, 2 + repetition)
        assert_equal(second.value, 3 * (5 + repetition))


def exercise_0_2(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(var first: Token, mut second: Token) {mut calls} -> Int:
        calls += 1
        second.value *= 3
        var total = 100 * first.value + second.value
        return total
    def fallible(var first: Token, mut second: Token) raises Failure {mut calls, fail} -> Int:
        calls += 1
        second.value *= 3
        if fail: raise Failure(40 + calls)
        var total = 100 * first.value + second.value
        return total
    for repetition in range(2):
        var first = Token(2 + repetition)
        var second = Token(5 + repetition)
        var observed = -1
        var code = 0
        if pure:
            if library:
                var captured: Result[Int, Never] = attempt(success, first^, second)
                observed = raise_on_err(captured^)
            else:
                observed = success(first^, second)
        else:
            if library:
                var captured: Result[Int, Failure] = attempt(fallible, first^, second)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first^, second)
                except error: code = error.code
        assert_equal(calls, repetition + 1)
        assert_equal(code, 41 + repetition if fail and not pure else 0)
        assert_equal(observed, -1 if fail and not pure else 100 * (2 + repetition) + 3 * (5 + repetition))
        assert_equal(second.value, 3 * (5 + repetition))


def exercise_0_3(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(mut first: Token, second: Token) {mut calls} -> Int:
        calls += 1
        first.value += 10
        var total = 100 * first.value + second.value
        return total
    def fallible(mut first: Token, second: Token) raises Failure {mut calls, fail} -> Int:
        calls += 1
        first.value += 10
        if fail: raise Failure(40 + calls)
        var total = 100 * first.value + second.value
        return total
    for repetition in range(2):
        var first = Token(2 + repetition)
        var second = Token(5 + repetition)
        var observed = -1
        var code = 0
        if pure:
            if library:
                var captured: Result[Int, Never] = attempt(success, first, second)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second)
        else:
            if library:
                var captured: Result[Int, Failure] = attempt(fallible, first, second)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second)
                except error: code = error.code
        assert_equal(calls, repetition + 1)
        assert_equal(code, 41 + repetition if fail and not pure else 0)
        assert_equal(observed, -1 if fail and not pure else 100 * (12 + repetition) + 5 + repetition)
        assert_equal(first.value, 12 + repetition)
        assert_equal(second.value, 5 + repetition)


def exercise_0_4(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(mut first: Token, var second: Token) {mut calls} -> Int:
        calls += 1
        first.value += 10
        var total = 100 * first.value + second.value
        return total
    def fallible(mut first: Token, var second: Token) raises Failure {mut calls, fail} -> Int:
        calls += 1
        first.value += 10
        if fail: raise Failure(40 + calls)
        var total = 100 * first.value + second.value
        return total
    for repetition in range(2):
        var first = Token(2 + repetition)
        var second = Token(5 + repetition)
        var observed = -1
        var code = 0
        if pure:
            if library:
                var captured: Result[Int, Never] = attempt(success, first, second^)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second^)
        else:
            if library:
                var captured: Result[Int, Failure] = attempt(fallible, first, second^)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second^)
                except error: code = error.code
        assert_equal(calls, repetition + 1)
        assert_equal(code, 41 + repetition if fail and not pure else 0)
        assert_equal(observed, -1 if fail and not pure else 100 * (12 + repetition) + 5 + repetition)
        assert_equal(first.value, 12 + repetition)


def exercise_0_5(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(mut first: Token, mut second: Token) {mut calls} -> Int:
        calls += 1
        first.value += 10
        second.value *= 3
        var total = 100 * first.value + second.value
        return total
    def fallible(mut first: Token, mut second: Token) raises Failure {mut calls, fail} -> Int:
        calls += 1
        first.value += 10
        second.value *= 3
        if fail: raise Failure(40 + calls)
        var total = 100 * first.value + second.value
        return total
    for repetition in range(2):
        var first = Token(2 + repetition)
        var second = Token(5 + repetition)
        var observed = -1
        var code = 0
        if pure:
            if library:
                var captured: Result[Int, Never] = attempt(success, first, second)
                observed = raise_on_err(captured^)
            else:
                observed = success(first, second)
        else:
            if library:
                var captured: Result[Int, Failure] = attempt(fallible, first, second)
                try: observed = raise_on_err(captured^)
                except error: code = error.code
            else:
                try: observed = fallible(first, second)
                except error: code = error.code
        assert_equal(calls, repetition + 1)
        assert_equal(code, 41 + repetition if fail and not pure else 0)
        assert_equal(observed, -1 if fail and not pure else 100 * (12 + repetition) + 3 * (5 + repetition))
        assert_equal(first.value, 12 + repetition)
        assert_equal(second.value, 3 * (5 + repetition))


def exercise_1_0(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(mut first: Token, /, var **values: Int) {mut calls} -> Int:
        calls += 1
        first.value += 10
        var total = 100 * first.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value
        return total
    def fallible(mut first: Token, /, var **values: Int) raises Failure {mut calls, fail} -> Int:
        calls += 1
        first.value += 10
        if fail: raise Failure(40 + calls)
        var total = 100 * first.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value
        return total
    for repetition in range(2):
        var first = Token(2 + repetition)
        var observed = -1
        var code = 0
        if count == 0:
            if pure:
                if library:
                    var captured: Result[Int, Never] = attempt(success, first)
                    observed = raise_on_err(captured^)
                else:
                    observed = success(first)
            else:
                if library:
                    var captured: Result[Int, Failure] = attempt(fallible, first)
                    try: observed = raise_on_err(captured^)
                    except error: code = error.code
                else:
                    try: observed = fallible(first)
                    except error: code = error.code
        elif count == 1:
            if pure:
                if library:
                    var captured: Result[Int, Never] = attempt(success, first, function=3)
                    observed = raise_on_err(captured^)
                else:
                    observed = success(first, function=3)
            else:
                if library:
                    var captured: Result[Int, Failure] = attempt(fallible, first, function=3)
                    try: observed = raise_on_err(captured^)
                    except error: code = error.code
                else:
                    try: observed = fallible(first, function=3)
                    except error: code = error.code
        elif count == 2:
            if pure:
                if library:
                    var captured: Result[Int, Never] = attempt(success, first, function=3, first=5)
                    observed = raise_on_err(captured^)
                else:
                    observed = success(first, function=3, first=5)
            else:
                if library:
                    var captured: Result[Int, Failure] = attempt(fallible, first, function=3, first=5)
                    try: observed = raise_on_err(captured^)
                    except error: code = error.code
                else:
                    try: observed = fallible(first, function=3, first=5)
                    except error: code = error.code
        assert_equal(calls, repetition + 1)
        assert_equal(code, 41 + repetition if fail and not pure else 0)
        assert_equal(observed, -1 if fail and not pure else 100 * (12 + repetition) + (0 if count == 0 else 24 if count == 1 else 49))
        assert_equal(first.value, 12 + repetition)


def exercise_1_1(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(first: Token, mut second: Token, /, var **values: Int) {mut calls} -> Int:
        calls += 1
        second.value *= 3
        var total = 100 * first.value + second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value
        return total
    def fallible(first: Token, mut second: Token, /, var **values: Int) raises Failure {mut calls, fail} -> Int:
        calls += 1
        second.value *= 3
        if fail: raise Failure(40 + calls)
        var total = 100 * first.value + second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value
        return total
    for repetition in range(2):
        var first = Token(2 + repetition)
        var second = Token(5 + repetition)
        var observed = -1
        var code = 0
        if count == 0:
            if pure:
                if library:
                    var captured: Result[Int, Never] = attempt(success, first, second)
                    observed = raise_on_err(captured^)
                else:
                    observed = success(first, second)
            else:
                if library:
                    var captured: Result[Int, Failure] = attempt(fallible, first, second)
                    try: observed = raise_on_err(captured^)
                    except error: code = error.code
                else:
                    try: observed = fallible(first, second)
                    except error: code = error.code
        elif count == 1:
            if pure:
                if library:
                    var captured: Result[Int, Never] = attempt(success, first, second, function=3)
                    observed = raise_on_err(captured^)
                else:
                    observed = success(first, second, function=3)
            else:
                if library:
                    var captured: Result[Int, Failure] = attempt(fallible, first, second, function=3)
                    try: observed = raise_on_err(captured^)
                    except error: code = error.code
                else:
                    try: observed = fallible(first, second, function=3)
                    except error: code = error.code
        elif count == 2:
            if pure:
                if library:
                    var captured: Result[Int, Never] = attempt(success, first, second, function=3, first=5)
                    observed = raise_on_err(captured^)
                else:
                    observed = success(first, second, function=3, first=5)
            else:
                if library:
                    var captured: Result[Int, Failure] = attempt(fallible, first, second, function=3, first=5)
                    try: observed = raise_on_err(captured^)
                    except error: code = error.code
                else:
                    try: observed = fallible(first, second, function=3, first=5)
                    except error: code = error.code
        assert_equal(calls, repetition + 1)
        assert_equal(code, 41 + repetition if fail and not pure else 0)
        assert_equal(observed, -1 if fail and not pure else 100 * (2 + repetition) + 3 * (5 + repetition) + (0 if count == 0 else 24 if count == 1 else 49))
        assert_equal(first.value, 2 + repetition)
        assert_equal(second.value, 3 * (5 + repetition))


def exercise_1_2(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(var first: Token, mut second: Token, /, var **values: Int) {mut calls} -> Int:
        calls += 1
        second.value *= 3
        var total = 100 * first.value + second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value
        return total
    def fallible(var first: Token, mut second: Token, /, var **values: Int) raises Failure {mut calls, fail} -> Int:
        calls += 1
        second.value *= 3
        if fail: raise Failure(40 + calls)
        var total = 100 * first.value + second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value
        return total
    for repetition in range(2):
        var first = Token(2 + repetition)
        var second = Token(5 + repetition)
        var observed = -1
        var code = 0
        if count == 0:
            if pure:
                if library:
                    var captured: Result[Int, Never] = attempt(success, first^, second)
                    observed = raise_on_err(captured^)
                else:
                    observed = success(first^, second)
            else:
                if library:
                    var captured: Result[Int, Failure] = attempt(fallible, first^, second)
                    try: observed = raise_on_err(captured^)
                    except error: code = error.code
                else:
                    try: observed = fallible(first^, second)
                    except error: code = error.code
        elif count == 1:
            if pure:
                if library:
                    var captured: Result[Int, Never] = attempt(success, first^, second, function=3)
                    observed = raise_on_err(captured^)
                else:
                    observed = success(first^, second, function=3)
            else:
                if library:
                    var captured: Result[Int, Failure] = attempt(fallible, first^, second, function=3)
                    try: observed = raise_on_err(captured^)
                    except error: code = error.code
                else:
                    try: observed = fallible(first^, second, function=3)
                    except error: code = error.code
        elif count == 2:
            if pure:
                if library:
                    var captured: Result[Int, Never] = attempt(success, first^, second, function=3, first=5)
                    observed = raise_on_err(captured^)
                else:
                    observed = success(first^, second, function=3, first=5)
            else:
                if library:
                    var captured: Result[Int, Failure] = attempt(fallible, first^, second, function=3, first=5)
                    try: observed = raise_on_err(captured^)
                    except error: code = error.code
                else:
                    try: observed = fallible(first^, second, function=3, first=5)
                    except error: code = error.code
        assert_equal(calls, repetition + 1)
        assert_equal(code, 41 + repetition if fail and not pure else 0)
        assert_equal(observed, -1 if fail and not pure else 100 * (2 + repetition) + 3 * (5 + repetition) + (0 if count == 0 else 24 if count == 1 else 49))
        assert_equal(second.value, 3 * (5 + repetition))


def exercise_1_3(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(mut first: Token, second: Token, /, var **values: Int) {mut calls} -> Int:
        calls += 1
        first.value += 10
        var total = 100 * first.value + second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value
        return total
    def fallible(mut first: Token, second: Token, /, var **values: Int) raises Failure {mut calls, fail} -> Int:
        calls += 1
        first.value += 10
        if fail: raise Failure(40 + calls)
        var total = 100 * first.value + second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value
        return total
    for repetition in range(2):
        var first = Token(2 + repetition)
        var second = Token(5 + repetition)
        var observed = -1
        var code = 0
        if count == 0:
            if pure:
                if library:
                    var captured: Result[Int, Never] = attempt(success, first, second)
                    observed = raise_on_err(captured^)
                else:
                    observed = success(first, second)
            else:
                if library:
                    var captured: Result[Int, Failure] = attempt(fallible, first, second)
                    try: observed = raise_on_err(captured^)
                    except error: code = error.code
                else:
                    try: observed = fallible(first, second)
                    except error: code = error.code
        elif count == 1:
            if pure:
                if library:
                    var captured: Result[Int, Never] = attempt(success, first, second, function=3)
                    observed = raise_on_err(captured^)
                else:
                    observed = success(first, second, function=3)
            else:
                if library:
                    var captured: Result[Int, Failure] = attempt(fallible, first, second, function=3)
                    try: observed = raise_on_err(captured^)
                    except error: code = error.code
                else:
                    try: observed = fallible(first, second, function=3)
                    except error: code = error.code
        elif count == 2:
            if pure:
                if library:
                    var captured: Result[Int, Never] = attempt(success, first, second, function=3, first=5)
                    observed = raise_on_err(captured^)
                else:
                    observed = success(first, second, function=3, first=5)
            else:
                if library:
                    var captured: Result[Int, Failure] = attempt(fallible, first, second, function=3, first=5)
                    try: observed = raise_on_err(captured^)
                    except error: code = error.code
                else:
                    try: observed = fallible(first, second, function=3, first=5)
                    except error: code = error.code
        assert_equal(calls, repetition + 1)
        assert_equal(code, 41 + repetition if fail and not pure else 0)
        assert_equal(observed, -1 if fail and not pure else 100 * (12 + repetition) + 5 + repetition + (0 if count == 0 else 24 if count == 1 else 49))
        assert_equal(first.value, 12 + repetition)
        assert_equal(second.value, 5 + repetition)


def exercise_1_4(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(mut first: Token, var second: Token, /, var **values: Int) {mut calls} -> Int:
        calls += 1
        first.value += 10
        var total = 100 * first.value + second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value
        return total
    def fallible(mut first: Token, var second: Token, /, var **values: Int) raises Failure {mut calls, fail} -> Int:
        calls += 1
        first.value += 10
        if fail: raise Failure(40 + calls)
        var total = 100 * first.value + second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value
        return total
    for repetition in range(2):
        var first = Token(2 + repetition)
        var second = Token(5 + repetition)
        var observed = -1
        var code = 0
        if count == 0:
            if pure:
                if library:
                    var captured: Result[Int, Never] = attempt(success, first, second^)
                    observed = raise_on_err(captured^)
                else:
                    observed = success(first, second^)
            else:
                if library:
                    var captured: Result[Int, Failure] = attempt(fallible, first, second^)
                    try: observed = raise_on_err(captured^)
                    except error: code = error.code
                else:
                    try: observed = fallible(first, second^)
                    except error: code = error.code
        elif count == 1:
            if pure:
                if library:
                    var captured: Result[Int, Never] = attempt(success, first, second^, function=3)
                    observed = raise_on_err(captured^)
                else:
                    observed = success(first, second^, function=3)
            else:
                if library:
                    var captured: Result[Int, Failure] = attempt(fallible, first, second^, function=3)
                    try: observed = raise_on_err(captured^)
                    except error: code = error.code
                else:
                    try: observed = fallible(first, second^, function=3)
                    except error: code = error.code
        elif count == 2:
            if pure:
                if library:
                    var captured: Result[Int, Never] = attempt(success, first, second^, function=3, first=5)
                    observed = raise_on_err(captured^)
                else:
                    observed = success(first, second^, function=3, first=5)
            else:
                if library:
                    var captured: Result[Int, Failure] = attempt(fallible, first, second^, function=3, first=5)
                    try: observed = raise_on_err(captured^)
                    except error: code = error.code
                else:
                    try: observed = fallible(first, second^, function=3, first=5)
                    except error: code = error.code
        assert_equal(calls, repetition + 1)
        assert_equal(code, 41 + repetition if fail and not pure else 0)
        assert_equal(observed, -1 if fail and not pure else 100 * (12 + repetition) + 5 + repetition + (0 if count == 0 else 24 if count == 1 else 49))
        assert_equal(first.value, 12 + repetition)


def exercise_1_5(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(mut first: Token, mut second: Token, /, var **values: Int) {mut calls} -> Int:
        calls += 1
        first.value += 10
        second.value *= 3
        var total = 100 * first.value + second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value
        return total
    def fallible(mut first: Token, mut second: Token, /, var **values: Int) raises Failure {mut calls, fail} -> Int:
        calls += 1
        first.value += 10
        second.value *= 3
        if fail: raise Failure(40 + calls)
        var total = 100 * first.value + second.value
        for entry in values.items(): total += entry.key.byte_length() * entry.value
        return total
    for repetition in range(2):
        var first = Token(2 + repetition)
        var second = Token(5 + repetition)
        var observed = -1
        var code = 0
        if count == 0:
            if pure:
                if library:
                    var captured: Result[Int, Never] = attempt(success, first, second)
                    observed = raise_on_err(captured^)
                else:
                    observed = success(first, second)
            else:
                if library:
                    var captured: Result[Int, Failure] = attempt(fallible, first, second)
                    try: observed = raise_on_err(captured^)
                    except error: code = error.code
                else:
                    try: observed = fallible(first, second)
                    except error: code = error.code
        elif count == 1:
            if pure:
                if library:
                    var captured: Result[Int, Never] = attempt(success, first, second, function=3)
                    observed = raise_on_err(captured^)
                else:
                    observed = success(first, second, function=3)
            else:
                if library:
                    var captured: Result[Int, Failure] = attempt(fallible, first, second, function=3)
                    try: observed = raise_on_err(captured^)
                    except error: code = error.code
                else:
                    try: observed = fallible(first, second, function=3)
                    except error: code = error.code
        elif count == 2:
            if pure:
                if library:
                    var captured: Result[Int, Never] = attempt(success, first, second, function=3, first=5)
                    observed = raise_on_err(captured^)
                else:
                    observed = success(first, second, function=3, first=5)
            else:
                if library:
                    var captured: Result[Int, Failure] = attempt(fallible, first, second, function=3, first=5)
                    try: observed = raise_on_err(captured^)
                    except error: code = error.code
                else:
                    try: observed = fallible(first, second, function=3, first=5)
                    except error: code = error.code
        assert_equal(calls, repetition + 1)
        assert_equal(code, 41 + repetition if fail and not pure else 0)
        assert_equal(observed, -1 if fail and not pure else 100 * (12 + repetition) + 3 * (5 + repetition) + (0 if count == 0 else 24 if count == 1 else 49))
        assert_equal(first.value, 12 + repetition)
        assert_equal(second.value, 3 * (5 + repetition))


def main() raises:
    for library in range(2):
        for pure in range(2):
            for fail in range(2):
                for count in range(3):
                    exercise_0_0(Bool(library), Bool(pure), Bool(fail), count)
                    exercise_0_1(Bool(library), Bool(pure), Bool(fail), count)
                    exercise_0_2(Bool(library), Bool(pure), Bool(fail), count)
                    exercise_0_3(Bool(library), Bool(pure), Bool(fail), count)
                    exercise_0_4(Bool(library), Bool(pure), Bool(fail), count)
                    exercise_0_5(Bool(library), Bool(pure), Bool(fail), count)
                    exercise_1_0(Bool(library), Bool(pure), Bool(fail), count)
                    exercise_1_1(Bool(library), Bool(pure), Bool(fail), count)
                    exercise_1_2(Bool(library), Bool(pure), Bool(fail), count)
                    exercise_1_3(Bool(library), Bool(pure), Bool(fail), count)
                    exercise_1_4(Bool(library), Bool(pure), Bool(fail), count)
                    exercise_1_5(Bool(library), Bool(pure), Bool(fail), count)
