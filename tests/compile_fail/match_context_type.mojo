# error: fp.match: clause 1 takes String as its second parameter
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

def main() raises:
    var n: N = Lit(1)
    _ = fp.match(n, lambda (l: Lit, k: Int) -> Int: l.value, lambda (p: Plus[Int], k: String) -> Int: p.left, context=3)
