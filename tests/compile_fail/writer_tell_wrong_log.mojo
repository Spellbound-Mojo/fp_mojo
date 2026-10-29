# error: cannot be converted
from fp.effects import Writer, writer
from fp.algebra import StringMonoid
from fp.functions import pipeline
def main():
    _ = pipeline(writer[Writer[StringMonoid],Int]((String("a"),7))).tell(3)
