# error: no matching method in call to 'map_err'
from fp.algebra import ResultFamily
from fp.effects import ReaderT
from fp.functions import pipeline
def size(mut error: String) -> Int: return error.byte_length()
def main():
    comptime I = ReaderT[ResultFamily[String],Int]
    _ = pipeline[I](I.pure(1)).map_err(size)
