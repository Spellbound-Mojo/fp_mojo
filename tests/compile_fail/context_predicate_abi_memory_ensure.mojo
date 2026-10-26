# error: no matching method in call to 'ensure'
from fp.functions import pipeline
from fp.data import Result, Ok, Err

def wrong(value: Int) -> String: return String("not a Bool")
def second(value: Int) -> String: return String(value)

def main():
    var predicate: def(Int) thin -> String = wrong
    _ = pipeline(Result[Int,String](Ok(1))).ensure(predicate,second).get()
