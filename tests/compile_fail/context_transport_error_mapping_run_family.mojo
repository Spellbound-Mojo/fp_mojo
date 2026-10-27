# error: no matching function in call to 'run'
from fp.algebra import ResultFamily
from fp.effects import ReaderT, run
from fp.functions import pipeline
def size(var error: String) -> Int: return error.byte_length()
def main():
    comptime I = ReaderT[ResultFamily[String],Int]
    var changed = pipeline[I](I.pure(1)).map_err(size).get()
    _ = run[I](changed^,0)
