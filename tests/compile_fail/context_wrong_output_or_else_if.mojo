# error: no matching method
# The first callback returns an incompatible type; admission must reject it.
from fp.functions import pipeline
from fp.data import Result, Ok

def first(value:String) -> Int: return 1
def second(var value:String) -> Result[Int,String]: return Ok(1)

def main():
    _ = pipeline(Result[Int,String](Ok(1))).or_else_if(first, second).get()
