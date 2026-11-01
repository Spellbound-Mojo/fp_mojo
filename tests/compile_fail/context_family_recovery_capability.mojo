# error: no matching method
from fp.functions import pipeline
from fp.algebra import IdentityFamily
from fp.effects import ResultT
from fp.data import Result, Ok
comptime I = ResultT[IdentityFamily,String]
def wrong(var value: Int) -> Int: return value
def main():
    _ = pipeline(1).or_else(wrong).get()
