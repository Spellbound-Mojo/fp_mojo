# error: no matching method
from fp.functions import pipeline
from fp.algebra import ListFamily
from fp.effects import ResultT
from fp.data import Result, Ok
comptime I=ResultT[ListFamily,String]
def wrong(error:String)->Int:return 0
def main():
    _ = pipeline[I](I.fail[Int](String("x"))).flat_tap_err(wrong).get()
