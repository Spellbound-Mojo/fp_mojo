# error: no matching method in call to 'map_err'
from fp.algebra import ResultFamily, StringMonoid, ListMonoid
from fp.effects import WriterT
from fp.functions import pipeline
def size(var error: String) -> Int: return error.byte_length()
def main():
    comptime I = WriterT[ResultFamily[String],StringMonoid]
    comptime T = WriterT[ResultFamily[Int],ListMonoid[Int]]
    _ = pipeline[I](I.pure(1)).map_err[Target=T](size)
