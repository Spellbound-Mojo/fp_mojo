# error: no matching method in call to 'map_err'
from fp.algebra import ResultFamily
from fp.effects import ReaderT, StateT
from fp.functions import pipeline
def size(var error: String) -> Int: return error.byte_length()
def main():
    comptime I = ReaderT[ResultFamily[String],Int]
    comptime T = ReaderT[StateT[ResultFamily[Int],Int],Int]
    _ = pipeline[I](I.pure(1)).map_err[Target=T](size)
