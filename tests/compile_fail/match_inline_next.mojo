# error: Next continues with a smaller Node, and the subject is not a Node
import fp
from fp.adt import Value, Cases, Choice, Data, Node
from fp.matching import Next

@fieldwise_init
struct Red(Copyable):
    pass

struct Light(Data):
    comptime Layer[R: Value] = Cases[Red]

def main():
    var c: Choice[Light] = Red()
    _ = fp.match(c, lambda (r: Red) -> Int: 0, lambda (x: Choice[Light]) -> Next[Node[Light]]: Next(Node[Light](Red())))
