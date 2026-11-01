# error: no matching method in call to 'map_err'
from fp.functions import pipeline
from fp.algebra import ListFamily, ResultFamily
from fp.effects import ResultT, OptionalT
from fp.data import Result, Ok, Err
def size(var error:String)->Int:return error.byte_length()
def main():
    comptime I=ResultT[ListFamily,String]
    _=pipeline[I](I.fail[Int](String("old"))).map_err[Target=ResultT[ListFamily,String]](size)
