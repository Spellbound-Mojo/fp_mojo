# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok
def accept(error: String) -> Bool: return True
def handler(var error: String) -> Result[Int,String]: return Ok(1)
def main():
    _ = pipeline(List[Int]([1])).or_else_if(accept,handler).get()
