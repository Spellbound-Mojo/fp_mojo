# error: constraint
from fp.effects import Reader, ask
@fieldwise_init
struct Env(Movable):
    var value: Int
def main(): _ = ask[Reader[Env]]()
