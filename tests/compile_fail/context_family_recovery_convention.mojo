# error: no matching method
from fp.functions import pipeline
from fp.algebra import IdentityFamily
from fp.effects import ResultT
from fp.data import Result, Ok
comptime I = ResultT[IdentityFamily,String]
def wrong(mut error: String) -> Int: return 0
def main():
    _ = pipeline[I](I.fail[Int](String("x"))).recover(wrong).get()
