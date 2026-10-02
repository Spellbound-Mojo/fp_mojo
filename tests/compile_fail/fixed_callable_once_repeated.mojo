# error: no matching function in call to 'call_repeated'
from fp.callables import OnceUnary, call_repeated


@fieldwise_init
struct Token(Movable):
    var id: Int


@fieldwise_init
struct Label(OnceUnary):
    var token: Token
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var value: Int) -> Int:
        return value + self.token.id


def main() raises:
    # A consuming-only receiver is never admitted where repeated calls are made.
    var once = Label(Token(1))
    _ = call_repeated(once, 1)
