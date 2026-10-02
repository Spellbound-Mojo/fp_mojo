# error: fp.match: clause 1 takes
import fp
from fp.adt import Value, Cases, Data, Node
from fp.matching import Next

@fieldwise_init
struct Lit(Copyable, Equatable):
    var value: Int

@fieldwise_init
struct Plus[R: Value](Movable):
    var left: Self.R
    var right: Self.R

struct Ex(Data):
    comptime Layer[R: Value] = Cases[Lit, Plus[R]]

comptime N = Node[Ex]

@fieldwise_init
struct Other(Copyable):
    var value: Int

def main() raises:
    var n: N = Lit(1)
    _ = fp.match(n, lambda (l: Lit) -> Int: l.value, lambda (o: Other) -> Int: 1, lambda (p: Plus[Int]) -> Int: 1)
