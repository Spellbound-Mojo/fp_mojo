# error: no matching method
from fp.functions import pipeline
from fp.algebra import ListFamily
from fp.effects import ResultT
from fp.data import Result, Ok
comptime I=ResultT[ListFamily,String]
def wrong(error:Int)->Int:return error
def main():
    _ = pipeline(1).tap_err(wrong).get()
