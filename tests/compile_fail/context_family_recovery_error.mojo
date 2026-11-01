# error: no matching method
from fp.functions import pipeline
from fp.algebra import IdentityFamily
from fp.effects import ResultT
from fp.data import Result, Ok
comptime I = ResultT[IdentityFamily,String]
def main() raises Int:
    var value = 0
    def wrong(var error: String) raises String {ref value} -> Int: raise String(value)
    _ = pipeline[I](I.fail[Int](String("x"))).raising[Int]().recover(wrong).get()
