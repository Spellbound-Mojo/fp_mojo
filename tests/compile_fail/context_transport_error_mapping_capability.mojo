# error: no matching method in call to 'map_err'
from fp.effects import Reader
from fp.functions import pipeline
def size(var error: String) -> Int: return error.byte_length()
def main():
    comptime I = Reader[Int]
    _ = pipeline[I](I.pure(1)).map_err(size)
