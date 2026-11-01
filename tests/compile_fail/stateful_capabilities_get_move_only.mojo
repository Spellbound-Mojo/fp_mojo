# error: constraint
from fp.effects import State, ReaderT, LiftStateful, get
@fieldwise_init
struct Token(Movable):
    var value: Int
def main():
    comptime S = State[Token]
    _ = get[LiftStateful[ReaderT[S, Int], S]]()
