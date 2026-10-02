# error: Choice: field left of Plus is recursive
from fp.adt import Value, Cases, Choice, Data

@fieldwise_init
struct Lit(Copyable):
    var value: Int

@fieldwise_init
struct Plus[R: Value](Movable):
    var left: Self.R
    var right: Self.R

struct Ex(Data):
    comptime Layer[R: Value] = Cases[Lit, Plus[R]]

def main():
    var c: Choice[Ex] = Lit(1)
    _ = c^
