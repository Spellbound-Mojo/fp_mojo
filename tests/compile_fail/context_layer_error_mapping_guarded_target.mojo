# error: no matching method in call to 'map_err'
from context_layer_error_mapping_support import MappingMonad
from fp.functions import pipeline
from fp.algebra import IdentityFamily
from fp.data import Result, Err

def size(var error:String)->Int:return error.byte_length()
def main():
    _=pipeline[MappingMonad[String]](Result[Int,String](Err(String("old")))).map_err[Target=IdentityFamily](size)
