# error: no matching method
from fp.functions import pipeline
from fp.data import Result,Ok
def first(var value:Int) raises String ->Int: raise String(value)
def second(var value:String) raises Int ->Int: raise value.byte_length()
def main():
    var left:def(var Int) raises String thin ->Int=first
    var right:def(var String) raises Int thin ->Int=second
    _ = pipeline(Result[Int,String](Ok(1))).raising[String]().map_both(left,right).get()
