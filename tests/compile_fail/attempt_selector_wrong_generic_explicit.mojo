# error: no matching function in call to 'attempt'
from fp.data import attempt, attempt_kwargs
@fieldwise_init
struct Token(Movable):
    var value: Int
def forward[A: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A) -> R](function: F, var value: A):
    _ = attempt[mutable=True, F=F](function, value^)
def callback(var value: Token) -> Int: return value.value
def main():
    forward(callback, Token(1))
