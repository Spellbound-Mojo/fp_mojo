# error: no matching method
from fp.functions import pipeline
from fp.effects import Reader, ResultT
comptime I = ResultT[Reader[Int],String]
def wrong(error: Int) -> Bool: return True
def handler(var error: String) -> Int: return 1
def main():
    _ = pipeline[I](I.fail[Int](String("x"))).recover_if(wrong,handler).get()
