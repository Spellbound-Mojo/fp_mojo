# error: fp.match: clause 1 raises a different error type
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
struct Oops(Movable):
    var code: Int

def raising_lit(l: Lit) raises -> Int:
    return l.value

def oops_plus(p: Plus[Int]) raises Oops -> Int:
    return p.left

def main() raises:
    var n: N = Lit(1)
    _ = fp.match(n, raising_lit, oops_plus)
