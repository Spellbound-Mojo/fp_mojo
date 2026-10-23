# error: constraint
from fp.algebra import StringMonoid, fail
from fp.effects import Writer, ResultT, LiftListen, listen
def main():
    comptime W = Writer[StringMonoid]
    comptime T = ResultT[W, String]
    _ = listen[LiftListen[T, W]](fail[ResultT[W, Int], Int](7))
