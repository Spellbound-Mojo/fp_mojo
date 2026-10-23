# error: constraint
from fp.effects import Listen, Writer, tell, listen
from fp.algebra import StringMonoid
def hear[C: Listen, V: Movable & Deinitable](var value: V) raises C.ListenError[V] -> C.Listened[V]:
    return listen[C](value^)
def main():
    comptime W = Writer[StringMonoid]
    _ = hear[W](tell[W](String("a")))
