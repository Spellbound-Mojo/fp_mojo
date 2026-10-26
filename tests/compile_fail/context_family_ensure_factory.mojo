# error: no matching method in call to 'ensure'
from fp.functions import pipeline
from fp.data import Result, Ok
from fp.algebra import ResultFamily
def predicate(value: Int) -> Bool: return False
def factory(value: Int) -> Int: return value
def main():
    _ = pipeline(Result[Int,String](Ok(1))).ensure(predicate,factory)
