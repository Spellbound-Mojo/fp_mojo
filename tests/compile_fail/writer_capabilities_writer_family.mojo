# error: constraint
from fp.algebra import Monoid, StringMonoid
from fp.effects import Writer, ReaderT, LiftListen, tell, listen
struct Other(Monoid):
    comptime Value = String
    @staticmethod
    def empty() -> String: return String()
    @staticmethod
    def combine(var left: String, var right: String) -> String: return left + right
def main():
    comptime W = Writer[StringMonoid]
    comptime OtherW = Writer[Other]
    comptime R = ReaderT[W, Int]
    _ = listen[LiftListen[R, W]](ReaderT[OtherW, Int].lift(tell[OtherW](String("a"))))
