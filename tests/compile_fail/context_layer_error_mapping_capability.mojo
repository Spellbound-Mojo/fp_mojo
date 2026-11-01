# error: no matching method in call to 'map_err'
from fp.functions import pipeline
from fp.algebra import ListFamily, ResultFamily
from fp.effects import ResultT, OptionalT
from fp.data import Result, Ok, Err
def size(var error:String)->Int:return error.byte_length()
def main():
    comptime I=OptionalT[ListFamily]
    _=pipeline[I](List[Optional[Int]]([Optional(1)])).map_err(size)
