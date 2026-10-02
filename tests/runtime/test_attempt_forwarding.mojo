"""All fixed attempt signatures agree with direct native calls and try/except."""
from fp.data import Result, attempt, raise_on_err
from std.testing import assert_equal

@fieldwise_init
struct Token(Movable):
    var value: Int

@fieldwise_init
struct Failure(Movable):
    var code: Int

def exercise_0_0(pure: Bool, library: Bool, negative: Bool) raises -> String:
    var calls = 0
    def success() {mut calls} -> String:
        calls += 1
        return String(7)
    def fallible() raises Failure {mut calls, negative} -> String:
        calls += 1
        if negative: raise Failure(42)
        return String(7)
    var output = String()
    var caught = False
    if pure:
        if library:
            var result = attempt(success)
            var typed: Result[String, Never] = result^
            output = raise_on_err(typed^)
        else:
            output = success()
    else:
        if library:
            var result = attempt(fallible)
            var typed: Result[String, Failure] = result^
            try: output = raise_on_err(typed^)
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try: output = fallible()
            except error:
                caught = True
                assert_equal(error.code, 42)
    assert_equal(calls, 1)
    assert_equal(caught, negative and not pure)
    return output^

def exercise_1_0(pure: Bool, library: Bool, negative: Bool) raises -> String:
    var calls = 0
    def success(first: Token) {mut calls} -> String:
        calls += 1
        return String(first.value)
    def fallible(first: Token) raises Failure {mut calls, negative} -> String:
        calls += 1
        if negative: raise Failure(42)
        return String(first.value)
    var output = String()
    var caught = False
    var left = Token(7)
    if pure:
        if library:
            var result = attempt(success, left)
            var typed: Result[String, Never] = result^
            output = raise_on_err(typed^)
        else:
            output = success(left)
    else:
        if library:
            var result = attempt(fallible, left)
            var typed: Result[String, Failure] = result^
            try: output = raise_on_err(typed^)
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try: output = fallible(left)
            except error:
                caught = True
                assert_equal(error.code, 42)
    assert_equal(left.value, 7)
    assert_equal(calls, 1)
    assert_equal(caught, negative and not pure)
    return output^

def exercise_1_1(pure: Bool, library: Bool, negative: Bool) raises -> String:
    var calls = 0
    def success(var first: Token) {mut calls} -> String:
        calls += 1
        return String(first.value)
    def fallible(var first: Token) raises Failure {mut calls, negative} -> String:
        calls += 1
        if negative: raise Failure(42)
        return String(first.value)
    var output = String()
    var caught = False
    var left = Token(7)
    if pure:
        if library:
            var result = attempt(success, left^)
            var typed: Result[String, Never] = result^
            output = raise_on_err(typed^)
        else:
            output = success(left^)
    else:
        if library:
            var result = attempt(fallible, left^)
            var typed: Result[String, Failure] = result^
            try: output = raise_on_err(typed^)
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try: output = fallible(left^)
            except error:
                caught = True
                assert_equal(error.code, 42)
    assert_equal(calls, 1)
    assert_equal(caught, negative and not pure)
    return output^

def exercise_2_0(pure: Bool, library: Bool, negative: Bool) raises -> String:
    var calls = 0
    def success(first: Token, second: String) {mut calls} -> String:
        calls += 1
        return String(first.value) + second
    def fallible(first: Token, second: String) raises Failure {mut calls, negative} -> String:
        calls += 1
        if negative: raise Failure(42)
        return String(first.value) + second
    var output = String()
    var caught = False
    var left = Token(7)
    var right = String("x")
    if pure:
        if library:
            var result = attempt(success, left, right)
            var typed: Result[String, Never] = result^
            output = raise_on_err(typed^)
        else:
            output = success(left, right)
    else:
        if library:
            var result = attempt(fallible, left, right)
            var typed: Result[String, Failure] = result^
            try: output = raise_on_err(typed^)
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try: output = fallible(left, right)
            except error:
                caught = True
                assert_equal(error.code, 42)
    assert_equal(left.value, 7)
    assert_equal(right, "x")
    assert_equal(calls, 1)
    assert_equal(caught, negative and not pure)
    return output^

def exercise_2_1(pure: Bool, library: Bool, negative: Bool) raises -> String:
    var calls = 0
    def success(var first: Token, second: String) {mut calls} -> String:
        calls += 1
        return String(first.value) + second
    def fallible(var first: Token, second: String) raises Failure {mut calls, negative} -> String:
        calls += 1
        if negative: raise Failure(42)
        return String(first.value) + second
    var output = String()
    var caught = False
    var left = Token(7)
    var right = String("x")
    if pure:
        if library:
            var result = attempt(success, left^, right)
            var typed: Result[String, Never] = result^
            output = raise_on_err(typed^)
        else:
            output = success(left^, right)
    else:
        if library:
            var result = attempt(fallible, left^, right)
            var typed: Result[String, Failure] = result^
            try: output = raise_on_err(typed^)
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try: output = fallible(left^, right)
            except error:
                caught = True
                assert_equal(error.code, 42)
    assert_equal(right, "x")
    assert_equal(calls, 1)
    assert_equal(caught, negative and not pure)
    return output^

def exercise_2_2(pure: Bool, library: Bool, negative: Bool) raises -> String:
    var calls = 0
    def success(first: Token, var second: String) {mut calls} -> String:
        calls += 1
        return String(first.value) + second
    def fallible(first: Token, var second: String) raises Failure {mut calls, negative} -> String:
        calls += 1
        if negative: raise Failure(42)
        return String(first.value) + second
    var output = String()
    var caught = False
    var left = Token(7)
    var right = String("x")
    if pure:
        if library:
            var result = attempt(success, left, right^)
            var typed: Result[String, Never] = result^
            output = raise_on_err(typed^)
        else:
            output = success(left, right^)
    else:
        if library:
            var result = attempt(fallible, left, right^)
            var typed: Result[String, Failure] = result^
            try: output = raise_on_err(typed^)
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try: output = fallible(left, right^)
            except error:
                caught = True
                assert_equal(error.code, 42)
    assert_equal(left.value, 7)
    assert_equal(calls, 1)
    assert_equal(caught, negative and not pure)
    return output^

def exercise_2_3(pure: Bool, library: Bool, negative: Bool) raises -> String:
    var calls = 0
    def success(var first: Token, var second: String) {mut calls} -> String:
        calls += 1
        return String(first.value) + second
    def fallible(var first: Token, var second: String) raises Failure {mut calls, negative} -> String:
        calls += 1
        if negative: raise Failure(42)
        return String(first.value) + second
    var output = String()
    var caught = False
    var left = Token(7)
    var right = String("x")
    if pure:
        if library:
            var result = attempt(success, left^, right^)
            var typed: Result[String, Never] = result^
            output = raise_on_err(typed^)
        else:
            output = success(left^, right^)
    else:
        if library:
            var result = attempt(fallible, left^, right^)
            var typed: Result[String, Failure] = result^
            try: output = raise_on_err(typed^)
            except error:
                caught = True
                assert_equal(error.code, 42)
        else:
            try: output = fallible(left^, right^)
            except error:
                caught = True
                assert_equal(error.code, 42)
    assert_equal(calls, 1)
    assert_equal(caught, negative and not pure)
    return output^

def main() raises:
    for pure in range(2):
        for negative in range(2):
            var expected_0_0 = exercise_0_0(Bool(pure), False, Bool(negative))
            assert_equal(exercise_0_0(Bool(pure), True, Bool(negative)), expected_0_0)
            assert_equal(expected_0_0, "7" if pure or not negative else "")
            var expected_1_0 = exercise_1_0(Bool(pure), False, Bool(negative))
            assert_equal(exercise_1_0(Bool(pure), True, Bool(negative)), expected_1_0)
            assert_equal(expected_1_0, "7" if pure or not negative else "")
            var expected_1_1 = exercise_1_1(Bool(pure), False, Bool(negative))
            assert_equal(exercise_1_1(Bool(pure), True, Bool(negative)), expected_1_1)
            assert_equal(expected_1_1, "7" if pure or not negative else "")
            var expected_2_0 = exercise_2_0(Bool(pure), False, Bool(negative))
            assert_equal(exercise_2_0(Bool(pure), True, Bool(negative)), expected_2_0)
            assert_equal(expected_2_0, "7x" if pure or not negative else "")
            var expected_2_1 = exercise_2_1(Bool(pure), False, Bool(negative))
            assert_equal(exercise_2_1(Bool(pure), True, Bool(negative)), expected_2_1)
            assert_equal(expected_2_1, "7x" if pure or not negative else "")
            var expected_2_2 = exercise_2_2(Bool(pure), False, Bool(negative))
            assert_equal(exercise_2_2(Bool(pure), True, Bool(negative)), expected_2_2)
            assert_equal(expected_2_2, "7x" if pure or not negative else "")
            var expected_2_3 = exercise_2_3(Bool(pure), False, Bool(negative))
            assert_equal(exercise_2_3(Bool(pure), True, Bool(negative)), expected_2_3)
            assert_equal(expected_2_3, "7x" if pure or not negative else "")
