# error: no matching method in call to 'recover_if'
from fp.functions import pipeline
from fp.data import Result, Ok, Err

def wrong(value: String) -> String: return String("not a Bool")
def second(var value: String) -> Int: return value.byte_length()

def main():
    var predicate: def(String) thin -> String = wrong
    _ = pipeline(Result[Int,String](Err(String("stored")))).recover_if(predicate,second).get()
