# error: no matching method in call to 'map_err'
from fp.functions import pipeline
from fp.algebra import ListFamily, ResultFamily
from fp.effects import ResultT, OptionalT
from fp.data import Result, Ok, Err
from context_layer_error_mapping_support import MappingMonad
def size(var error:String)->Int:return error.byte_length()
def main():
    comptime I=OptionalT[ResultFamily[String]]
    _=pipeline[I](I.fail[Int](String("old"))).map_err[Target=OptionalT[MappingMonad[Int]]](size)
