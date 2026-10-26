# error: no matching method
from fp.functions import pipeline
from fp.effects import Reader, ResultT
comptime I = ResultT[Reader[Int],String]
def main():
    var value = 1
    def wrong(error: String) raises String {ref value} -> Bool: raise String(value)
    def handler(var error: String) raises Int -> Int: raise 1
    _ = pipeline[I](I.fail[Int](String("x"))).raising[Int]().recover_if(wrong,handler).get()
