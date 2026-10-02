# error: does not have witness table for trait 'std::traits::copyable::Copyable'
from fp.iteration import fold_left
from std.iter import iter

@fieldwise_init
struct Token(Movable):
    var value: Int

def consume(var total: Int, var token: Token) -> Int:
    return total + token.value

def main():
    var values: List[Token] = [Token(1)]
    # An owned iterator is supported; a borrowed source cannot implicitly give
    # away each move-only element as an owned callback argument.
    print(fold_left(consume, 0, iter(values)))
