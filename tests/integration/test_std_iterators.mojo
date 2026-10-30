from std.iter import iter, map, chain
from fp.iteration import fold_left, reduce_optional
from std.testing import assert_equal


def double(var value: Int) -> Int:
    return value * 2


def add(var total: Int, var value: Int) -> Int:
    return total + value


@fieldwise_init
struct Token(Movable):
    var value: Int


def add_token(var total: Int, var token: Token) -> Int:
    return total + token.value


def main() raises:
    var values: List[Int] = [1, 2, 3]
    assert_equal(fold_left(iter(values), 0, add), 6)
    assert_equal(len(values), 3)
    var mapped = map[double](values)
    assert_equal(fold_left(mapped^, 0, add), 12)
    var first: List[Int] = [1, 2]
    var second: List[Int] = [3, 4]
    var chained = chain(first, second)
    assert_equal(fold_left(chained^, 0, add), 10)
    var tokens: List[Token] = [Token(2), Token(3)]
    assert_equal(fold_left(iter(tokens^), 0, add_token), 5)
