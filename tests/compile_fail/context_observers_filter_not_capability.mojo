# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok
def predicate(value: Int) -> Bool: return True
def main(): _ = pipeline(Result[Int,String](Ok(1))).filter_not(predicate).get()
