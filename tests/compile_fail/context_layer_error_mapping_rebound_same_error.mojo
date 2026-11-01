# error: no matching method in call to 'map_err'
from context_layer_error_mapping_support import TypedList
from fp.algebra import ErrorMapping
from fp.effects import ResultT
from fp.functions import pipeline
from fp.data import Result

def tag(var error:String)->String:return "mapped:"+error
def main():
    comptime I=ResultT[TypedList[Result[Int,String],False],String]
    comptime Candidate=I.DefaultErrorTarget[Int,String]
    comptime assert conforms_to(Candidate,ErrorMapping)
    _=pipeline[I](I.fail[Int](String("old"))).map_err(tag)
