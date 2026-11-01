# error: use of uninitialized value
from fp.effects import State, ResultT, LiftStateful, put
@fieldwise_init
struct Token(Movable):
    var value: Int
def main():
    comptime S = State[Token]
    comptime C = LiftStateful[ResultT[S, String], S]
    var token = Token(1)
    _ = put[C](token^)
    _ = put[C](token^)
