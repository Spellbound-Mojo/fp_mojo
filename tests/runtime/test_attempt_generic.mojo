"""Two generic returns preserve every admitted argument convention and exact errors."""
from fp.data import Result, attempt, raise_on_err
from std.testing import assert_equal

@fieldwise_init
struct Input(Movable):
    var value: Int

@fieldwise_init
struct AttemptFailure(Movable):
    var code: Int

def capture[R: Movable & Deinitable, //, F: def() -> R](
    function: F
) -> Result[R, Never]:
    return attempt(function)

def capture[R: Movable & Deinitable, X: Movable & Deinitable, //, F: def() raises X -> R](
    function: F
) -> Result[R, X]:
    return attempt(function)

def forward[R: Movable & Deinitable, //, F: def() -> R](
    function: F
) -> Result[R, Never]:
    return capture(function)

def forward[R: Movable & Deinitable, X: Movable & Deinitable, //, F: def() raises X -> R](
    function: F
) -> Result[R, X]:
    return capture(function)

def capture[A: Movable & Deinitable, R: Movable & Deinitable, //, F: def(A) -> R](
    function: F, first: A
) -> Result[R, Never] where not conforms_to(A, TrivialRegisterPassable):
    return attempt(function, first)

def capture[A: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(A) raises X -> R](
    function: F, first: A
) -> Result[R, X] where not conforms_to(A, TrivialRegisterPassable):
    return attempt(function, first)

def forward[A: Movable & Deinitable, R: Movable & Deinitable, //, F: def(A) -> R](
    function: F, first: A
) -> Result[R, Never] where not conforms_to(A, TrivialRegisterPassable):
    return capture(function, first)

def forward[A: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(A) raises X -> R](
    function: F, first: A
) -> Result[R, X] where not conforms_to(A, TrivialRegisterPassable):
    return capture(function, first)

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

def capture[A: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A) -> R](
    function: F, mut first: A
) -> Result[R, Never]:
    return attempt(function, first)

def capture[A: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A) raises X -> R](
    function: F, mut first: A
) -> Result[R, X]:
    return attempt(function, first)

def forward[A: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A) -> R](
    function: F, mut first: A
) -> Result[R, Never]:
    return capture(function, first)

def forward[A: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A) raises X -> R](
    function: F, mut first: A
) -> Result[R, X]:
    return capture(function, first)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(A, B) -> R](
    function: F, first: A, second: B
) -> Result[R, Never] where not conforms_to(A, TrivialRegisterPassable) and not conforms_to(B, TrivialRegisterPassable):
    return attempt(function, first, second)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(A, B) raises X -> R](
    function: F, first: A, second: B
) -> Result[R, X] where not conforms_to(A, TrivialRegisterPassable) and not conforms_to(B, TrivialRegisterPassable):
    return attempt(function, first, second)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(A, B) -> R](
    function: F, first: A, second: B
) -> Result[R, Never] where not conforms_to(A, TrivialRegisterPassable) and not conforms_to(B, TrivialRegisterPassable):
    return capture(function, first, second)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(A, B) raises X -> R](
    function: F, first: A, second: B
) -> Result[R, X] where not conforms_to(A, TrivialRegisterPassable) and not conforms_to(B, TrivialRegisterPassable):
    return capture(function, first, second)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(A, var B) -> R](
    function: F, first: A, var second: B
) -> Result[R, Never] where not conforms_to(A, TrivialRegisterPassable):
    return attempt(function, first, second^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(A, var B) raises X -> R](
    function: F, first: A, var second: B
) -> Result[R, X] where not conforms_to(A, TrivialRegisterPassable):
    return attempt(function, first, second^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(A, var B) -> R](
    function: F, first: A, var second: B
) -> Result[R, Never] where not conforms_to(A, TrivialRegisterPassable):
    return capture(function, first, second^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(A, var B) raises X -> R](
    function: F, first: A, var second: B
) -> Result[R, X] where not conforms_to(A, TrivialRegisterPassable):
    return capture(function, first, second^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(A, mut B) -> R](
    function: F, first: A, mut second: B
) -> Result[R, Never] where not conforms_to(A, TrivialRegisterPassable):
    return attempt(function, first, second)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(A, mut B) raises X -> R](
    function: F, first: A, mut second: B
) -> Result[R, X] where not conforms_to(A, TrivialRegisterPassable):
    return attempt(function, first, second)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(A, mut B) -> R](
    function: F, first: A, mut second: B
) -> Result[R, Never] where not conforms_to(A, TrivialRegisterPassable):
    return capture(function, first, second)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(A, mut B) raises X -> R](
    function: F, first: A, mut second: B
) -> Result[R, X] where not conforms_to(A, TrivialRegisterPassable):
    return capture(function, first, second)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, B) -> R](
    function: F, var first: A, second: B
) -> Result[R, Never] where not conforms_to(B, TrivialRegisterPassable):
    return attempt(function, first^, second)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, B) raises X -> R](
    function: F, var first: A, second: B
) -> Result[R, X] where not conforms_to(B, TrivialRegisterPassable):
    return attempt(function, first^, second)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, B) -> R](
    function: F, var first: A, second: B
) -> Result[R, Never] where not conforms_to(B, TrivialRegisterPassable):
    return capture(function, first^, second)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, B) raises X -> R](
    function: F, var first: A, second: B
) -> Result[R, X] where not conforms_to(B, TrivialRegisterPassable):
    return capture(function, first^, second)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, var B) -> R](
    function: F, var first: A, var second: B
) -> Result[R, Never]:
    return attempt(function, first^, second^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, var B) raises X -> R](
    function: F, var first: A, var second: B
) -> Result[R, X]:
    return attempt(function, first^, second^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, var B) -> R](
    function: F, var first: A, var second: B
) -> Result[R, Never]:
    return capture(function, first^, second^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, var B) raises X -> R](
    function: F, var first: A, var second: B
) -> Result[R, X]:
    return capture(function, first^, second^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, mut B) -> R](
    function: F, var first: A, mut second: B
) -> Result[R, Never]:
    return attempt(function, first^, second)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, mut B) raises X -> R](
    function: F, var first: A, mut second: B
) -> Result[R, X]:
    return attempt(function, first^, second)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, mut B) -> R](
    function: F, var first: A, mut second: B
) -> Result[R, Never]:
    return capture(function, first^, second)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, mut B) raises X -> R](
    function: F, var first: A, mut second: B
) -> Result[R, X]:
    return capture(function, first^, second)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, B) -> R](
    function: F, mut first: A, second: B
) -> Result[R, Never] where not conforms_to(B, TrivialRegisterPassable):
    return attempt(function, first, second)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, B) raises X -> R](
    function: F, mut first: A, second: B
) -> Result[R, X] where not conforms_to(B, TrivialRegisterPassable):
    return attempt(function, first, second)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, B) -> R](
    function: F, mut first: A, second: B
) -> Result[R, Never] where not conforms_to(B, TrivialRegisterPassable):
    return capture(function, first, second)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, B) raises X -> R](
    function: F, mut first: A, second: B
) -> Result[R, X] where not conforms_to(B, TrivialRegisterPassable):
    return capture(function, first, second)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, var B) -> R](
    function: F, mut first: A, var second: B
) -> Result[R, Never]:
    return attempt(function, first, second^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, var B) raises X -> R](
    function: F, mut first: A, var second: B
) -> Result[R, X]:
    return attempt(function, first, second^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, var B) -> R](
    function: F, mut first: A, var second: B
) -> Result[R, Never]:
    return capture(function, first, second^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, var B) raises X -> R](
    function: F, mut first: A, var second: B
) -> Result[R, X]:
    return capture(function, first, second^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, mut B) -> R](
    function: F, mut first: A, mut second: B
) -> Result[R, Never]:
    return attempt(function, first, second)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, mut B) raises X -> R](
    function: F, mut first: A, mut second: B
) -> Result[R, X]:
    return attempt(function, first, second)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, mut B) -> R](
    function: F, mut first: A, mut second: B
) -> Result[R, Never]:
    return capture(function, first, second)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, mut B) raises X -> R](
    function: F, mut first: A, mut second: B
) -> Result[R, X]:
    return capture(function, first, second)

def check_0(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success() {mut calls, fail} -> String:
        calls += 1
        var total = 17
        return String(total)
    def failure() raises AttemptFailure {mut calls, fail} -> String:
        calls += 1
        var total = 17
        if fail: raise AttemptFailure(100 + total)
        return String(total)
    for repetition in range(2):
        var observed = String()
        var error_code = 0
        if pure:
            if library:
                var result: Result[String, Never] = forward(success)
                observed = raise_on_err(result^)
            else:
                observed = success()
        else:
            if library:
                var result: Result[String, AttemptFailure] = forward(failure)
                try: observed = raise_on_err(result^)
                except error: error_code = error.code
            else:
                try: observed = failure()
                except error: error_code = error.code
        var expected = 17
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)

def check_1(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(first: Input) {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value
        return String(total)
    def failure(first: Input) raises AttemptFailure {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value
        if fail: raise AttemptFailure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if library:
                var result: Result[String, Never] = forward(success, first)
                observed = raise_on_err(result^)
            else:
                observed = success(first)
        else:
            if library:
                var result: Result[String, AttemptFailure] = forward(failure, first)
                try: observed = raise_on_err(result^)
                except error: error_code = error.code
            else:
                try: observed = failure(first)
                except error: error_code = error.code
        var expected = 2 * (3 + repetition)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(first.value, 3 + repetition)

def check_2(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(var first: Input) {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value
        return String(total)
    def failure(var first: Input) raises AttemptFailure {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value
        if fail: raise AttemptFailure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if library:
                var result: Result[String, Never] = forward(success, first^)
                observed = raise_on_err(result^)
            else:
                observed = success(first^)
        else:
            if library:
                var result: Result[String, AttemptFailure] = forward(failure, first^)
                try: observed = raise_on_err(result^)
                except error: error_code = error.code
            else:
                try: observed = failure(first^)
                except error: error_code = error.code
        var expected = 2 * (3 + repetition)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)

def check_3(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(mut first: Input) {mut calls, fail} -> String:
        calls += 1
        first.value += 7
        var total = 2 * first.value
        return String(total)
    def failure(mut first: Input) raises AttemptFailure {mut calls, fail} -> String:
        calls += 1
        first.value += 7
        var total = 2 * first.value
        if fail: raise AttemptFailure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if library:
                var result: Result[String, Never] = forward(success, first)
                observed = raise_on_err(result^)
            else:
                observed = success(first)
        else:
            if library:
                var result: Result[String, AttemptFailure] = forward(failure, first)
                try: observed = raise_on_err(result^)
                except error: error_code = error.code
            else:
                try: observed = failure(first)
                except error: error_code = error.code
        var expected = 2 * (3 + repetition + 7)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(first.value, 3 + repetition + 7)

def check_4(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(first: Input, second: Input) {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value + 3 * second.value
        return String(total)
    def failure(first: Input, second: Input) raises AttemptFailure {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value + 3 * second.value
        if fail: raise AttemptFailure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var second = Input(5 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if library:
                var result: Result[String, Never] = forward(success, first, second)
                observed = raise_on_err(result^)
            else:
                observed = success(first, second)
        else:
            if library:
                var result: Result[String, AttemptFailure] = forward(failure, first, second)
                try: observed = raise_on_err(result^)
                except error: error_code = error.code
            else:
                try: observed = failure(first, second)
                except error: error_code = error.code
        var expected = 2 * (3 + repetition) + 3 * (5 + repetition)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(first.value, 3 + repetition)
        assert_equal(second.value, 5 + repetition)

def check_5(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(first: Input, var second: Input) {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value + 3 * second.value
        return String(total)
    def failure(first: Input, var second: Input) raises AttemptFailure {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value + 3 * second.value
        if fail: raise AttemptFailure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var second = Input(5 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if library:
                var result: Result[String, Never] = forward(success, first, second^)
                observed = raise_on_err(result^)
            else:
                observed = success(first, second^)
        else:
            if library:
                var result: Result[String, AttemptFailure] = forward(failure, first, second^)
                try: observed = raise_on_err(result^)
                except error: error_code = error.code
            else:
                try: observed = failure(first, second^)
                except error: error_code = error.code
        var expected = 2 * (3 + repetition) + 3 * (5 + repetition)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(first.value, 3 + repetition)

def check_6(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(first: Input, mut second: Input) {mut calls, fail} -> String:
        calls += 1
        second.value += 11
        var total = 2 * first.value + 3 * second.value
        return String(total)
    def failure(first: Input, mut second: Input) raises AttemptFailure {mut calls, fail} -> String:
        calls += 1
        second.value += 11
        var total = 2 * first.value + 3 * second.value
        if fail: raise AttemptFailure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var second = Input(5 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if library:
                var result: Result[String, Never] = forward(success, first, second)
                observed = raise_on_err(result^)
            else:
                observed = success(first, second)
        else:
            if library:
                var result: Result[String, AttemptFailure] = forward(failure, first, second)
                try: observed = raise_on_err(result^)
                except error: error_code = error.code
            else:
                try: observed = failure(first, second)
                except error: error_code = error.code
        var expected = 2 * (3 + repetition) + 3 * (5 + repetition + 11)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(first.value, 3 + repetition)
        assert_equal(second.value, 5 + repetition + 11)

def check_7(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(var first: Input, second: Input) {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value + 3 * second.value
        return String(total)
    def failure(var first: Input, second: Input) raises AttemptFailure {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value + 3 * second.value
        if fail: raise AttemptFailure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var second = Input(5 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if library:
                var result: Result[String, Never] = forward(success, first^, second)
                observed = raise_on_err(result^)
            else:
                observed = success(first^, second)
        else:
            if library:
                var result: Result[String, AttemptFailure] = forward(failure, first^, second)
                try: observed = raise_on_err(result^)
                except error: error_code = error.code
            else:
                try: observed = failure(first^, second)
                except error: error_code = error.code
        var expected = 2 * (3 + repetition) + 3 * (5 + repetition)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(second.value, 5 + repetition)

def check_8(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(var first: Input, var second: Input) {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value + 3 * second.value
        return String(total)
    def failure(var first: Input, var second: Input) raises AttemptFailure {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value + 3 * second.value
        if fail: raise AttemptFailure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var second = Input(5 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if library:
                var result: Result[String, Never] = forward(success, first^, second^)
                observed = raise_on_err(result^)
            else:
                observed = success(first^, second^)
        else:
            if library:
                var result: Result[String, AttemptFailure] = forward(failure, first^, second^)
                try: observed = raise_on_err(result^)
                except error: error_code = error.code
            else:
                try: observed = failure(first^, second^)
                except error: error_code = error.code
        var expected = 2 * (3 + repetition) + 3 * (5 + repetition)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)

def check_9(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(var first: Input, mut second: Input) {mut calls, fail} -> String:
        calls += 1
        second.value += 11
        var total = 2 * first.value + 3 * second.value
        return String(total)
    def failure(var first: Input, mut second: Input) raises AttemptFailure {mut calls, fail} -> String:
        calls += 1
        second.value += 11
        var total = 2 * first.value + 3 * second.value
        if fail: raise AttemptFailure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var second = Input(5 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if library:
                var result: Result[String, Never] = forward(success, first^, second)
                observed = raise_on_err(result^)
            else:
                observed = success(first^, second)
        else:
            if library:
                var result: Result[String, AttemptFailure] = forward(failure, first^, second)
                try: observed = raise_on_err(result^)
                except error: error_code = error.code
            else:
                try: observed = failure(first^, second)
                except error: error_code = error.code
        var expected = 2 * (3 + repetition) + 3 * (5 + repetition + 11)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(second.value, 5 + repetition + 11)

def check_10(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(mut first: Input, second: Input) {mut calls, fail} -> String:
        calls += 1
        first.value += 7
        var total = 2 * first.value + 3 * second.value
        return String(total)
    def failure(mut first: Input, second: Input) raises AttemptFailure {mut calls, fail} -> String:
        calls += 1
        first.value += 7
        var total = 2 * first.value + 3 * second.value
        if fail: raise AttemptFailure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var second = Input(5 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if library:
                var result: Result[String, Never] = forward(success, first, second)
                observed = raise_on_err(result^)
            else:
                observed = success(first, second)
        else:
            if library:
                var result: Result[String, AttemptFailure] = forward(failure, first, second)
                try: observed = raise_on_err(result^)
                except error: error_code = error.code
            else:
                try: observed = failure(first, second)
                except error: error_code = error.code
        var expected = 2 * (3 + repetition + 7) + 3 * (5 + repetition)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(first.value, 3 + repetition + 7)
        assert_equal(second.value, 5 + repetition)

def check_11(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(mut first: Input, var second: Input) {mut calls, fail} -> String:
        calls += 1
        first.value += 7
        var total = 2 * first.value + 3 * second.value
        return String(total)
    def failure(mut first: Input, var second: Input) raises AttemptFailure {mut calls, fail} -> String:
        calls += 1
        first.value += 7
        var total = 2 * first.value + 3 * second.value
        if fail: raise AttemptFailure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var second = Input(5 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if library:
                var result: Result[String, Never] = forward(success, first, second^)
                observed = raise_on_err(result^)
            else:
                observed = success(first, second^)
        else:
            if library:
                var result: Result[String, AttemptFailure] = forward(failure, first, second^)
                try: observed = raise_on_err(result^)
                except error: error_code = error.code
            else:
                try: observed = failure(first, second^)
                except error: error_code = error.code
        var expected = 2 * (3 + repetition + 7) + 3 * (5 + repetition)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(first.value, 3 + repetition + 7)

def check_12(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(mut first: Input, mut second: Input) {mut calls, fail} -> String:
        calls += 1
        first.value += 7
        second.value += 11
        var total = 2 * first.value + 3 * second.value
        return String(total)
    def failure(mut first: Input, mut second: Input) raises AttemptFailure {mut calls, fail} -> String:
        calls += 1
        first.value += 7
        second.value += 11
        var total = 2 * first.value + 3 * second.value
        if fail: raise AttemptFailure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var second = Input(5 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if library:
                var result: Result[String, Never] = forward(success, first, second)
                observed = raise_on_err(result^)
            else:
                observed = success(first, second)
        else:
            if library:
                var result: Result[String, AttemptFailure] = forward(failure, first, second)
                try: observed = raise_on_err(result^)
                except error: error_code = error.code
            else:
                try: observed = failure(first, second)
                except error: error_code = error.code
        var expected = 2 * (3 + repetition + 7) + 3 * (5 + repetition + 11)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(first.value, 3 + repetition + 7)
        assert_equal(second.value, 5 + repetition + 11)

def main() raises:
    for library in range(2):
        for pure in range(2):
            for fail in range(2):
                for count in range(2):
                    check_0(Bool(library), Bool(pure), Bool(fail), 2 * count)
                    check_1(Bool(library), Bool(pure), Bool(fail), 2 * count)
                    check_2(Bool(library), Bool(pure), Bool(fail), 2 * count)
                    check_3(Bool(library), Bool(pure), Bool(fail), 2 * count)
                    check_4(Bool(library), Bool(pure), Bool(fail), 2 * count)
                    check_5(Bool(library), Bool(pure), Bool(fail), 2 * count)
                    check_6(Bool(library), Bool(pure), Bool(fail), 2 * count)
                    check_7(Bool(library), Bool(pure), Bool(fail), 2 * count)
                    check_8(Bool(library), Bool(pure), Bool(fail), 2 * count)
                    check_9(Bool(library), Bool(pure), Bool(fail), 2 * count)
                    check_10(Bool(library), Bool(pure), Bool(fail), 2 * count)
                    check_11(Bool(library), Bool(pure), Bool(fail), 2 * count)
                    check_12(Bool(library), Bool(pure), Bool(fail), 2 * count)
