# error: no matching method in call to 'map_err'
from fp.functions import pipeline
from fp.algebra import ListFamily, ResultFamily
from fp.effects import ResultT, OptionalT
from fp.data import Result, Ok, Err
from outcome_admission_support import Restricted
def size(var error:String)->Int:return error.byte_length()
def main():
    comptime I=ResultT[Restricted[True,False,True,True],String]
    _=pipeline[I](Result[Result[Int,String],String](Ok(Result[Int,String](Ok(1))))).map_err(size)
