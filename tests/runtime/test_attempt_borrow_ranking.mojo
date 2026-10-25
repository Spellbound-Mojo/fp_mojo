"""Read callbacks retain shared borrows when mutable overloads are also visible."""
from fp.data import Result, attempt, attempt_kwargs, raise_on_err
from std.testing import assert_equal


@fieldwise_init
struct AttemptRankingInput(Movable):
    var value: Int


@fieldwise_init
struct AttemptRankingFailure(Movable):
    var code: Int


def read(value: AttemptRankingInput) -> Int:
    return value.value


def fail(value: AttemptRankingInput) raises AttemptRankingFailure -> Int:
    raise AttemptRankingFailure(value.value)


def forward_read[A: Movable & Deinitable, R: Movable & Deinitable, //,
                 F: def(A) -> R](function: F, value: A) -> Result[R, Never] where not conforms_to(A, TrivialRegisterPassable):
    return attempt(function, value)


def forward_raising[A: Movable & Deinitable, R: Movable & Deinitable,
                    E: Movable & Deinitable, //,
                    F: def(A) raises E -> R](function: F, value: A) -> Result[R, E] where not conforms_to(A, TrivialRegisterPassable):
    return attempt(function, value)


def main() raises:
    var owner = AttemptRankingInput(7)
    var inferred = attempt(read, owner)
    comptime assert type_of(inferred) == Result[Int, Never]
    assert_equal(raise_on_err(inferred^), 7)
    assert_equal(raise_on_err(attempt[type_of(read)](read, owner)), 7)
    assert_equal(raise_on_err(forward_read(read, owner)), 7)

    var failed = forward_raising(fail, owner)
    comptime assert type_of(failed) == Result[Int, AttemptRankingFailure]
    var code = 0
    try:
        _ = raise_on_err(failed^)
    except error:
        code = error.code
    assert_equal(code, 7)

    var explicit_error = attempt[type_of(fail)](fail, owner)
    code = 0
    try:
        _ = raise_on_err(explicit_error^)
    except error:
        code = error.code
    assert_equal(code, 7)

    var calls = 0
    def pair(first: AttemptRankingInput, second: AttemptRankingInput) {mut calls} -> Int:
        calls += 1
        return first.value + second.value

    def pair_error(first: AttemptRankingInput, second: AttemptRankingInput) raises AttemptRankingFailure {mut calls} -> Int:
        calls += 1
        raise AttemptRankingFailure(first.value + second.value)

    # Reusing the same owner requires both parameters to remain shared borrows.
    for _ in range(2):
        var summed = attempt(pair, owner, owner)
        comptime assert type_of(summed) == Result[Int, Never]
        assert_equal(raise_on_err(summed^), 14)
        var rejected = attempt(pair_error, owner, owner)
        comptime assert type_of(rejected) == Result[Int, AttemptRankingFailure]
        code = 0
        try:
            _ = raise_on_err(rejected^)
        except error:
            code = error.code
        assert_equal(code, 14)
    assert_equal(calls, 4)

    def keyword_pair(first: AttemptRankingInput, second: AttemptRankingInput, /, var **values: Int) {mut calls} -> Int:
        calls += 1
        return first.value + second.value + len(values)

    def keyword_error(first: AttemptRankingInput, second: AttemptRankingInput, /, var **values: Int) raises AttemptRankingFailure {mut calls} -> Int:
        calls += 1
        raise AttemptRankingFailure(first.value + second.value + len(values))

    var empty = attempt_kwargs(keyword_pair, owner, owner)
    comptime assert type_of(empty) == Result[Int, Never]
    assert_equal(raise_on_err(empty^), 14)
    assert_equal(raise_on_err(attempt_kwargs(keyword_pair, owner, owner, extra=1)), 15)
    var keyword_failed = attempt_kwargs(keyword_error, owner, owner, extra=1)
    comptime assert type_of(keyword_failed) == Result[Int, AttemptRankingFailure]
    try:
        _ = raise_on_err(keyword_failed^)
    except error:
        code = error.code
    assert_equal(code, 15)
    assert_equal(calls, 7)
    assert_equal(owner.value, 7)
