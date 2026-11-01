# error: no matching method
from fp.functions import pipeline
from fp.algebra import ListFamily
from fp.effects import ResultT
from fp.data import Result, Ok
comptime I=ResultT[ListFamily,String]
def main() raises Int:
    var state=0
    def wrong(error:String) raises String {ref state} ->Int:raise String(state)
    _ = pipeline[I](I.fail[Int](String("x"))).raising[Int]().tap_err(wrong).get()
