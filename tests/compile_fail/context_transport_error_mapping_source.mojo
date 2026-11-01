# error: no matching method in call to 'map_err'
from fp.algebra import ResultFamily
from fp.effects import ReaderT
from fp.functions import pipeline
def size(var error: String) -> Int: return error.byte_length()
def main():
    comptime I = ReaderT[ResultFamily[String],Int]
    comptime Other = ReaderT[ResultFamily[String],String]
    _ = pipeline[I](Other.pure(1)).map_err(size)
