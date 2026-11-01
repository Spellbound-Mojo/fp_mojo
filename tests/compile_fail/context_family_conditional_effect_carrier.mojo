# error: no matching method
from fp.functions import pipeline
from fp.effects import Reader, ResultT
comptime I = ResultT[Reader[Int],String]
def accept(error: String) -> Bool: return True
def wrong(var error: String) -> Optional[Int]: return Optional(1)
def main():
    _ = pipeline[I](I.fail[Int](String("x"))).or_else_if(accept,wrong).get()
