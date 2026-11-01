# error: use of uninitialized value
from fp.effects import Writer, writer
from fp.algebra import StringMonoid
from fp.functions import pipeline
def main():
    var value = pipeline(writer[Writer[StringMonoid],Int]((String("a"),7)))
    _ = value^.tell("b")
    _ = value^.tell("c")
