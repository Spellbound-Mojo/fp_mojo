# error: no matching method in call to 'map_err'
from fp.algebra import ResultFamily
from fp.effects import ReaderT
from fp.functions import pipeline
from context_layer_error_mapping_support import MappingMonad

def size(var error: String) -> Int: return error.byte_length()

def main():
    comptime I = ReaderT[MappingMonad[String],Int]
    comptime Target = ReaderT[ResultFamily[Int],Int]
    # Both targets support mapping, but the base rejects this policy before
    # projecting its deliberately unavailable output type.
    _ = pipeline[I](I.pure(1)).map_err[Target=Target](size)
