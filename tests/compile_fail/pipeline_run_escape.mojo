# error: origin
from fp.functions import pipeline
from fp.effects import Reader
def escape() -> Span[Int, ImmUntrackedOrigin]:
    var owner: List[Int] = [3]
    return pipeline(Reader[Int].pure(Span(owner))).run(0)
def main(): _ = escape()
