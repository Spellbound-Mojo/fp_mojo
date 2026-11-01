# error: violated constraint
from fp.effects import Writer, WriterValue, run_log
from fp.algebra import StringMonoid
def main():
    comptime W = Writer[StringMonoid]
    _ = run_log[W](WriterValue[W,Int,String](String("wrong")))
