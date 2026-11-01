# error: no matching method in call to 'map_err'
from context_layer_error_mapping_support import TypedList
from fp.effects import ResultT
from fp.functions import pipeline
from fp.data import Result

def size(var error:String)->Int:return error.byte_length()
def main():
    comptime I=ResultT[TypedList[Result[Int,String],False],String]
    _=pipeline[I](I.fail[Int](String("old"))).map_err(size)
