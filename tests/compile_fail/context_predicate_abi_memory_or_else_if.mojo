# error: no matching method in call to 'or_else_if'
from fp.functions import pipeline
from fp.data import Result, Ok, Err

def wrong(value: String) -> String: return String("not a Bool")
def second(var value: String) -> Result[Int,String]: return Ok(value.byte_length())

def main():
    var predicate: def(String) thin -> String = wrong
    _ = pipeline(Result[Int,String](Err(String("stored")))).or_else_if(predicate,second).get()
