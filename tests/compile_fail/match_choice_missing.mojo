# error: fp.match: constructor Green has no clause that cannot decline
import fp
from fp.adt import Value, Cases, Choice, Data

@fieldwise_init
struct Red(Copyable):
    pass

@fieldwise_init
struct Green(Copyable):
    var shade: Int

struct Light(Data):
    comptime Layer[R: Value] = Cases[Red, Green]

def main():
    var c: Choice[Light] = Red()
    _ = fp.match(c,
        lambda (r: Red) -> Int: 0,
        fp.when[lambda (g: Green) -> Bool: g.shade > 1, lambda (g: Green) -> Int: g.shade])
