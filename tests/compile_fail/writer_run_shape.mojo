# error: no matching
from fp.effects import Writer, WriterValue, run
from fp.algebra import StringMonoid
def main():
    comptime W = Writer[StringMonoid]
    _ = run[W](WriterValue[W,Int,String](String("wrong")))
