# error: constraint
from fp.algebra import StringMonoid
from fp.effects import Writer, ReaderT, LiftCensor, censor, tell
def wrong(var log: String) -> Int: return log.byte_length()
def main():
    comptime W = Writer[StringMonoid]
    comptime C = LiftCensor[ReaderT[W, Int], W]
    _ = censor[C](wrong, tell[C](String("a")))
