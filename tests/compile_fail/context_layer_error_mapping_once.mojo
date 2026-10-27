# error: repeatable
from fp.algebra import ListFamily
from fp.effects import ResultT
from fp.callables import OnceUnary
from fp.functions import pipeline
@fieldwise_init
struct OnceError(OnceUnary):
    comptime Arg=String
    comptime Out=Int
    def call_once(deinit self,var error:String)->Int:return error.byte_length()
def main():
    comptime I=ResultT[ListFamily,String]
    _=pipeline[I](I.fail[Int](String("old"))).map_err(OnceError())
