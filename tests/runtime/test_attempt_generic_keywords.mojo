"""Two generic returns preserve every admitted argument convention and exact errors."""
from fp.data import Result, attempt, raise_on_err
from std.testing import assert_equal

@fieldwise_init
struct Input(Movable):
    var value: Int

@fieldwise_init
struct Failure(Movable):
    var code: Int

def capture[K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var **kwargs: K) -> R](
    function: F, /, var **values: K
) -> Result[R, Never]:
    return attempt(function, **values^)

def capture[K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var **kwargs: K) raises X -> R](
    function: F, /, var **values: K
) -> Result[R, X]:
    return attempt(function, **values^)

def forward[K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var **kwargs: K) -> R](
    function: F, /, var **values: K
) -> Result[R, Never]:
    return capture(function, **values^)

def forward[K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var **kwargs: K) raises X -> R](
    function: F, /, var **values: K
) -> Result[R, X]:
    return capture(function, **values^)

def capture[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(A, /, var **kwargs: K) -> R](
    function: F, first: A, /, var **values: K
) -> Result[R, Never] where not conforms_to(A, TrivialRegisterPassable):
    return attempt(function, first, **values^)

def capture[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(A, /, var **kwargs: K) raises X -> R](
    function: F, first: A, /, var **values: K
) -> Result[R, X] where not conforms_to(A, TrivialRegisterPassable):
    return attempt(function, first, **values^)

def forward[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(A, /, var **kwargs: K) -> R](
    function: F, first: A, /, var **values: K
) -> Result[R, Never] where not conforms_to(A, TrivialRegisterPassable):
    return capture(function, first, **values^)

def forward[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(A, /, var **kwargs: K) raises X -> R](
    function: F, first: A, /, var **values: K
) -> Result[R, X] where not conforms_to(A, TrivialRegisterPassable):
    return capture(function, first, **values^)

def capture[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, /, var **kwargs: K) -> R](
    function: F, var first: A, /, var **values: K
) -> Result[R, Never]:
    return attempt(function, first^, **values^)

def capture[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, /, var **kwargs: K) raises X -> R](
    function: F, var first: A, /, var **values: K
) -> Result[R, X]:
    return attempt(function, first^, **values^)

def forward[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, /, var **kwargs: K) -> R](
    function: F, var first: A, /, var **values: K
) -> Result[R, Never]:
    return capture(function, first^, **values^)

def forward[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, /, var **kwargs: K) raises X -> R](
    function: F, var first: A, /, var **values: K
) -> Result[R, X]:
    return capture(function, first^, **values^)

def capture[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, /, var **kwargs: K) -> R](
    function: F, mut first: A, /, var **values: K
) -> Result[R, Never]:
    return attempt(function, first, **values^)

def capture[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, /, var **kwargs: K) raises X -> R](
    function: F, mut first: A, /, var **values: K
) -> Result[R, X]:
    return attempt(function, first, **values^)

def forward[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, /, var **kwargs: K) -> R](
    function: F, mut first: A, /, var **values: K
) -> Result[R, Never]:
    return capture(function, first, **values^)

def forward[A: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, /, var **kwargs: K) raises X -> R](
    function: F, mut first: A, /, var **values: K
) -> Result[R, X]:
    return capture(function, first, **values^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(A, B, /, var **kwargs: K) -> R](
    function: F, first: A, second: B, /, var **values: K
) -> Result[R, Never] where not conforms_to(A, TrivialRegisterPassable) and not conforms_to(B, TrivialRegisterPassable):
    return attempt(function, first, second, **values^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(A, B, /, var **kwargs: K) raises X -> R](
    function: F, first: A, second: B, /, var **values: K
) -> Result[R, X] where not conforms_to(A, TrivialRegisterPassable) and not conforms_to(B, TrivialRegisterPassable):
    return attempt(function, first, second, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(A, B, /, var **kwargs: K) -> R](
    function: F, first: A, second: B, /, var **values: K
) -> Result[R, Never] where not conforms_to(A, TrivialRegisterPassable) and not conforms_to(B, TrivialRegisterPassable):
    return capture(function, first, second, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(A, B, /, var **kwargs: K) raises X -> R](
    function: F, first: A, second: B, /, var **values: K
) -> Result[R, X] where not conforms_to(A, TrivialRegisterPassable) and not conforms_to(B, TrivialRegisterPassable):
    return capture(function, first, second, **values^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(A, var B, /, var **kwargs: K) -> R](
    function: F, first: A, var second: B, /, var **values: K
) -> Result[R, Never] where not conforms_to(A, TrivialRegisterPassable):
    return attempt(function, first, second^, **values^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(A, var B, /, var **kwargs: K) raises X -> R](
    function: F, first: A, var second: B, /, var **values: K
) -> Result[R, X] where not conforms_to(A, TrivialRegisterPassable):
    return attempt(function, first, second^, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(A, var B, /, var **kwargs: K) -> R](
    function: F, first: A, var second: B, /, var **values: K
) -> Result[R, Never] where not conforms_to(A, TrivialRegisterPassable):
    return capture(function, first, second^, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(A, var B, /, var **kwargs: K) raises X -> R](
    function: F, first: A, var second: B, /, var **values: K
) -> Result[R, X] where not conforms_to(A, TrivialRegisterPassable):
    return capture(function, first, second^, **values^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(A, mut B, /, var **kwargs: K) -> R](
    function: F, first: A, mut second: B, /, var **values: K
) -> Result[R, Never] where not conforms_to(A, TrivialRegisterPassable):
    return attempt(function, first, second, **values^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(A, mut B, /, var **kwargs: K) raises X -> R](
    function: F, first: A, mut second: B, /, var **values: K
) -> Result[R, X] where not conforms_to(A, TrivialRegisterPassable):
    return attempt(function, first, second, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(A, mut B, /, var **kwargs: K) -> R](
    function: F, first: A, mut second: B, /, var **values: K
) -> Result[R, Never] where not conforms_to(A, TrivialRegisterPassable):
    return capture(function, first, second, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(A, mut B, /, var **kwargs: K) raises X -> R](
    function: F, first: A, mut second: B, /, var **values: K
) -> Result[R, X] where not conforms_to(A, TrivialRegisterPassable):
    return capture(function, first, second, **values^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, B, /, var **kwargs: K) -> R](
    function: F, var first: A, second: B, /, var **values: K
) -> Result[R, Never] where not conforms_to(B, TrivialRegisterPassable):
    return attempt(function, first^, second, **values^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, B, /, var **kwargs: K) raises X -> R](
    function: F, var first: A, second: B, /, var **values: K
) -> Result[R, X] where not conforms_to(B, TrivialRegisterPassable):
    return attempt(function, first^, second, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, B, /, var **kwargs: K) -> R](
    function: F, var first: A, second: B, /, var **values: K
) -> Result[R, Never] where not conforms_to(B, TrivialRegisterPassable):
    return capture(function, first^, second, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, B, /, var **kwargs: K) raises X -> R](
    function: F, var first: A, second: B, /, var **values: K
) -> Result[R, X] where not conforms_to(B, TrivialRegisterPassable):
    return capture(function, first^, second, **values^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, var B, /, var **kwargs: K) -> R](
    function: F, var first: A, var second: B, /, var **values: K
) -> Result[R, Never]:
    return attempt(function, first^, second^, **values^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, var B, /, var **kwargs: K) raises X -> R](
    function: F, var first: A, var second: B, /, var **values: K
) -> Result[R, X]:
    return attempt(function, first^, second^, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, var B, /, var **kwargs: K) -> R](
    function: F, var first: A, var second: B, /, var **values: K
) -> Result[R, Never]:
    return capture(function, first^, second^, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, var B, /, var **kwargs: K) raises X -> R](
    function: F, var first: A, var second: B, /, var **values: K
) -> Result[R, X]:
    return capture(function, first^, second^, **values^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, mut B, /, var **kwargs: K) -> R](
    function: F, var first: A, mut second: B, /, var **values: K
) -> Result[R, Never]:
    return attempt(function, first^, second, **values^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, mut B, /, var **kwargs: K) raises X -> R](
    function: F, var first: A, mut second: B, /, var **values: K
) -> Result[R, X]:
    return attempt(function, first^, second, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A, mut B, /, var **kwargs: K) -> R](
    function: F, var first: A, mut second: B, /, var **values: K
) -> Result[R, Never]:
    return capture(function, first^, second, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var A, mut B, /, var **kwargs: K) raises X -> R](
    function: F, var first: A, mut second: B, /, var **values: K
) -> Result[R, X]:
    return capture(function, first^, second, **values^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, B, /, var **kwargs: K) -> R](
    function: F, mut first: A, second: B, /, var **values: K
) -> Result[R, Never] where not conforms_to(B, TrivialRegisterPassable):
    return attempt(function, first, second, **values^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, B, /, var **kwargs: K) raises X -> R](
    function: F, mut first: A, second: B, /, var **values: K
) -> Result[R, X] where not conforms_to(B, TrivialRegisterPassable):
    return attempt(function, first, second, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, B, /, var **kwargs: K) -> R](
    function: F, mut first: A, second: B, /, var **values: K
) -> Result[R, Never] where not conforms_to(B, TrivialRegisterPassable):
    return capture(function, first, second, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, B, /, var **kwargs: K) raises X -> R](
    function: F, mut first: A, second: B, /, var **values: K
) -> Result[R, X] where not conforms_to(B, TrivialRegisterPassable):
    return capture(function, first, second, **values^)

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

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, mut B, /, var **kwargs: K) -> R](
    function: F, mut first: A, mut second: B, /, var **values: K
) -> Result[R, Never]:
    return attempt(function, first, second, **values^)

def capture[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, mut B, /, var **kwargs: K) raises X -> R](
    function: F, mut first: A, mut second: B, /, var **values: K
) -> Result[R, X]:
    return attempt(function, first, second, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, //, F: def(mut A, mut B, /, var **kwargs: K) -> R](
    function: F, mut first: A, mut second: B, /, var **values: K
) -> Result[R, Never]:
    return capture(function, first, second, **values^)

def forward[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: def(mut A, mut B, /, var **kwargs: K) raises X -> R](
    function: F, mut first: A, mut second: B, /, var **values: K
) -> Result[R, X]:
    return capture(function, first, second, **values^)

def check_0(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(var **options: Int) {mut calls, fail} -> String:
        calls += 1
        var total = 17
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        return String(total)
    def failure(var **options: Int) raises Failure {mut calls, fail} -> String:
        calls += 1
        var total = 17
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        if fail: raise Failure(100 + total)
        return String(total)
    for repetition in range(2):
        var observed = String()
        var error_code = 0
        if pure:
            if count == 0:
                if library:
                    var result: Result[String, Never] = forward(success)
                    observed = raise_on_err(result^)
                else:
                    observed = success()
            else:
                if library:
                    var result: Result[String, Never] = forward(success, function=3, first=5)
                    observed = raise_on_err(result^)
                else:
                    observed = success(function=3, first=5)
        else:
            if count == 0:
                if library:
                    var result: Result[String, Failure] = forward(failure)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure()
                    except error: error_code = error.code
            else:
                if library:
                    var result: Result[String, Failure] = forward(failure, function=3, first=5)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(function=3, first=5)
                    except error: error_code = error.code
        var expected = 17 + (0 if count == 0 else 49)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)

def check_1(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(first: Input, /, var **options: Int) {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        return String(total)
    def failure(first: Input, /, var **options: Int) raises Failure {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        if fail: raise Failure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if count == 0:
                if library:
                    var result: Result[String, Never] = forward(success, first)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first)
            else:
                if library:
                    var result: Result[String, Never] = forward(success, first, function=3, first=5)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first, function=3, first=5)
        else:
            if count == 0:
                if library:
                    var result: Result[String, Failure] = forward(failure, first)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first)
                    except error: error_code = error.code
            else:
                if library:
                    var result: Result[String, Failure] = forward(failure, first, function=3, first=5)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first, function=3, first=5)
                    except error: error_code = error.code
        var expected = 2 * (3 + repetition) + (0 if count == 0 else 49)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(first.value, 3 + repetition)

def check_2(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(var first: Input, /, var **options: Int) {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        return String(total)
    def failure(var first: Input, /, var **options: Int) raises Failure {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        if fail: raise Failure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if count == 0:
                if library:
                    var result: Result[String, Never] = forward(success, first^)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first^)
            else:
                if library:
                    var result: Result[String, Never] = forward(success, first^, function=3, first=5)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first^, function=3, first=5)
        else:
            if count == 0:
                if library:
                    var result: Result[String, Failure] = forward(failure, first^)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first^)
                    except error: error_code = error.code
            else:
                if library:
                    var result: Result[String, Failure] = forward(failure, first^, function=3, first=5)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first^, function=3, first=5)
                    except error: error_code = error.code
        var expected = 2 * (3 + repetition) + (0 if count == 0 else 49)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)

def check_3(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(mut first: Input, /, var **options: Int) {mut calls, fail} -> String:
        calls += 1
        first.value += 7
        var total = 2 * first.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        return String(total)
    def failure(mut first: Input, /, var **options: Int) raises Failure {mut calls, fail} -> String:
        calls += 1
        first.value += 7
        var total = 2 * first.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        if fail: raise Failure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if count == 0:
                if library:
                    var result: Result[String, Never] = forward(success, first)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first)
            else:
                if library:
                    var result: Result[String, Never] = forward(success, first, function=3, first=5)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first, function=3, first=5)
        else:
            if count == 0:
                if library:
                    var result: Result[String, Failure] = forward(failure, first)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first)
                    except error: error_code = error.code
            else:
                if library:
                    var result: Result[String, Failure] = forward(failure, first, function=3, first=5)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first, function=3, first=5)
                    except error: error_code = error.code
        var expected = 2 * (3 + repetition + 7) + (0 if count == 0 else 49)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(first.value, 3 + repetition + 7)

def check_4(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(first: Input, second: Input, /, var **options: Int) {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value + 3 * second.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        return String(total)
    def failure(first: Input, second: Input, /, var **options: Int) raises Failure {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value + 3 * second.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        if fail: raise Failure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var second = Input(5 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if count == 0:
                if library:
                    var result: Result[String, Never] = forward(success, first, second)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first, second)
            else:
                if library:
                    var result: Result[String, Never] = forward(success, first, second, function=3, first=5)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first, second, function=3, first=5)
        else:
            if count == 0:
                if library:
                    var result: Result[String, Failure] = forward(failure, first, second)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first, second)
                    except error: error_code = error.code
            else:
                if library:
                    var result: Result[String, Failure] = forward(failure, first, second, function=3, first=5)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first, second, function=3, first=5)
                    except error: error_code = error.code
        var expected = 2 * (3 + repetition) + 3 * (5 + repetition) + (0 if count == 0 else 49)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(first.value, 3 + repetition)
        assert_equal(second.value, 5 + repetition)

def check_5(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(first: Input, var second: Input, /, var **options: Int) {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value + 3 * second.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        return String(total)
    def failure(first: Input, var second: Input, /, var **options: Int) raises Failure {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value + 3 * second.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        if fail: raise Failure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var second = Input(5 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if count == 0:
                if library:
                    var result: Result[String, Never] = forward(success, first, second^)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first, second^)
            else:
                if library:
                    var result: Result[String, Never] = forward(success, first, second^, function=3, first=5)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first, second^, function=3, first=5)
        else:
            if count == 0:
                if library:
                    var result: Result[String, Failure] = forward(failure, first, second^)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first, second^)
                    except error: error_code = error.code
            else:
                if library:
                    var result: Result[String, Failure] = forward(failure, first, second^, function=3, first=5)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first, second^, function=3, first=5)
                    except error: error_code = error.code
        var expected = 2 * (3 + repetition) + 3 * (5 + repetition) + (0 if count == 0 else 49)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(first.value, 3 + repetition)

def check_6(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(first: Input, mut second: Input, /, var **options: Int) {mut calls, fail} -> String:
        calls += 1
        second.value += 11
        var total = 2 * first.value + 3 * second.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        return String(total)
    def failure(first: Input, mut second: Input, /, var **options: Int) raises Failure {mut calls, fail} -> String:
        calls += 1
        second.value += 11
        var total = 2 * first.value + 3 * second.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        if fail: raise Failure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var second = Input(5 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if count == 0:
                if library:
                    var result: Result[String, Never] = forward(success, first, second)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first, second)
            else:
                if library:
                    var result: Result[String, Never] = forward(success, first, second, function=3, first=5)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first, second, function=3, first=5)
        else:
            if count == 0:
                if library:
                    var result: Result[String, Failure] = forward(failure, first, second)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first, second)
                    except error: error_code = error.code
            else:
                if library:
                    var result: Result[String, Failure] = forward(failure, first, second, function=3, first=5)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first, second, function=3, first=5)
                    except error: error_code = error.code
        var expected = 2 * (3 + repetition) + 3 * (5 + repetition + 11) + (0 if count == 0 else 49)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(first.value, 3 + repetition)
        assert_equal(second.value, 5 + repetition + 11)

def check_7(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(var first: Input, second: Input, /, var **options: Int) {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value + 3 * second.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        return String(total)
    def failure(var first: Input, second: Input, /, var **options: Int) raises Failure {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value + 3 * second.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        if fail: raise Failure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var second = Input(5 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if count == 0:
                if library:
                    var result: Result[String, Never] = forward(success, first^, second)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first^, second)
            else:
                if library:
                    var result: Result[String, Never] = forward(success, first^, second, function=3, first=5)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first^, second, function=3, first=5)
        else:
            if count == 0:
                if library:
                    var result: Result[String, Failure] = forward(failure, first^, second)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first^, second)
                    except error: error_code = error.code
            else:
                if library:
                    var result: Result[String, Failure] = forward(failure, first^, second, function=3, first=5)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first^, second, function=3, first=5)
                    except error: error_code = error.code
        var expected = 2 * (3 + repetition) + 3 * (5 + repetition) + (0 if count == 0 else 49)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(second.value, 5 + repetition)

def check_8(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(var first: Input, var second: Input, /, var **options: Int) {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value + 3 * second.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        return String(total)
    def failure(var first: Input, var second: Input, /, var **options: Int) raises Failure {mut calls, fail} -> String:
        calls += 1
        var total = 2 * first.value + 3 * second.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        if fail: raise Failure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var second = Input(5 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if count == 0:
                if library:
                    var result: Result[String, Never] = forward(success, first^, second^)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first^, second^)
            else:
                if library:
                    var result: Result[String, Never] = forward(success, first^, second^, function=3, first=5)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first^, second^, function=3, first=5)
        else:
            if count == 0:
                if library:
                    var result: Result[String, Failure] = forward(failure, first^, second^)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first^, second^)
                    except error: error_code = error.code
            else:
                if library:
                    var result: Result[String, Failure] = forward(failure, first^, second^, function=3, first=5)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first^, second^, function=3, first=5)
                    except error: error_code = error.code
        var expected = 2 * (3 + repetition) + 3 * (5 + repetition) + (0 if count == 0 else 49)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)

def check_9(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(var first: Input, mut second: Input, /, var **options: Int) {mut calls, fail} -> String:
        calls += 1
        second.value += 11
        var total = 2 * first.value + 3 * second.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        return String(total)
    def failure(var first: Input, mut second: Input, /, var **options: Int) raises Failure {mut calls, fail} -> String:
        calls += 1
        second.value += 11
        var total = 2 * first.value + 3 * second.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        if fail: raise Failure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var second = Input(5 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if count == 0:
                if library:
                    var result: Result[String, Never] = forward(success, first^, second)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first^, second)
            else:
                if library:
                    var result: Result[String, Never] = forward(success, first^, second, function=3, first=5)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first^, second, function=3, first=5)
        else:
            if count == 0:
                if library:
                    var result: Result[String, Failure] = forward(failure, first^, second)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first^, second)
                    except error: error_code = error.code
            else:
                if library:
                    var result: Result[String, Failure] = forward(failure, first^, second, function=3, first=5)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first^, second, function=3, first=5)
                    except error: error_code = error.code
        var expected = 2 * (3 + repetition) + 3 * (5 + repetition + 11) + (0 if count == 0 else 49)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(second.value, 5 + repetition + 11)

def check_10(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(mut first: Input, second: Input, /, var **options: Int) {mut calls, fail} -> String:
        calls += 1
        first.value += 7
        var total = 2 * first.value + 3 * second.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        return String(total)
    def failure(mut first: Input, second: Input, /, var **options: Int) raises Failure {mut calls, fail} -> String:
        calls += 1
        first.value += 7
        var total = 2 * first.value + 3 * second.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        if fail: raise Failure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var second = Input(5 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if count == 0:
                if library:
                    var result: Result[String, Never] = forward(success, first, second)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first, second)
            else:
                if library:
                    var result: Result[String, Never] = forward(success, first, second, function=3, first=5)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first, second, function=3, first=5)
        else:
            if count == 0:
                if library:
                    var result: Result[String, Failure] = forward(failure, first, second)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first, second)
                    except error: error_code = error.code
            else:
                if library:
                    var result: Result[String, Failure] = forward(failure, first, second, function=3, first=5)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first, second, function=3, first=5)
                    except error: error_code = error.code
        var expected = 2 * (3 + repetition + 7) + 3 * (5 + repetition) + (0 if count == 0 else 49)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(first.value, 3 + repetition + 7)
        assert_equal(second.value, 5 + repetition)

def check_11(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(mut first: Input, var second: Input, /, var **options: Int) {mut calls, fail} -> String:
        calls += 1
        first.value += 7
        var total = 2 * first.value + 3 * second.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        return String(total)
    def failure(mut first: Input, var second: Input, /, var **options: Int) raises Failure {mut calls, fail} -> String:
        calls += 1
        first.value += 7
        var total = 2 * first.value + 3 * second.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        if fail: raise Failure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var second = Input(5 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if count == 0:
                if library:
                    var result: Result[String, Never] = forward(success, first, second^)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first, second^)
            else:
                if library:
                    var result: Result[String, Never] = forward(success, first, second^, function=3, first=5)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first, second^, function=3, first=5)
        else:
            if count == 0:
                if library:
                    var result: Result[String, Failure] = forward(failure, first, second^)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first, second^)
                    except error: error_code = error.code
            else:
                if library:
                    var result: Result[String, Failure] = forward(failure, first, second^, function=3, first=5)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first, second^, function=3, first=5)
                    except error: error_code = error.code
        var expected = 2 * (3 + repetition + 7) + 3 * (5 + repetition) + (0 if count == 0 else 49)
        assert_equal(observed, String() if fail and not pure else String(expected))
        assert_equal(error_code, 100 + expected if fail and not pure else 0)
        assert_equal(calls, repetition + 1)
        assert_equal(first.value, 3 + repetition + 7)

def check_12(library: Bool, pure: Bool, fail: Bool, count: Int) raises:
    var calls = 0
    def success(mut first: Input, mut second: Input, /, var **options: Int) {mut calls, fail} -> String:
        calls += 1
        first.value += 7
        second.value += 11
        var total = 2 * first.value + 3 * second.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        return String(total)
    def failure(mut first: Input, mut second: Input, /, var **options: Int) raises Failure {mut calls, fail} -> String:
        calls += 1
        first.value += 7
        second.value += 11
        var total = 2 * first.value + 3 * second.value
        for entry in options.items(): total += entry.key.byte_length() * entry.value
        if fail: raise Failure(100 + total)
        return String(total)
    for repetition in range(2):
        var first = Input(3 + repetition)
        var second = Input(5 + repetition)
        var observed = String()
        var error_code = 0
        if pure:
            if count == 0:
                if library:
                    var result: Result[String, Never] = forward(success, first, second)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first, second)
            else:
                if library:
                    var result: Result[String, Never] = forward(success, first, second, function=3, first=5)
                    observed = raise_on_err(result^)
                else:
                    observed = success(first, second, function=3, first=5)
        else:
            if count == 0:
                if library:
                    var result: Result[String, Failure] = forward(failure, first, second)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first, second)
                    except error: error_code = error.code
            else:
                if library:
                    var result: Result[String, Failure] = forward(failure, first, second, function=3, first=5)
                    try: observed = raise_on_err(result^)
                    except error: error_code = error.code
                else:
                    try: observed = failure(first, second, function=3, first=5)
                    except error: error_code = error.code
        var expected = 2 * (3 + repetition + 7) + 3 * (5 + repetition + 11) + (0 if count == 0 else 49)
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
