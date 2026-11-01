# error: no matching method in call to 'ensure'
from fp.functions import pipeline
from fp.data import Result, Ok
from fp.algebra import ResultFamily
def predicate(value: Int) raises Int -> Bool: return False
def factory(value: Int) raises String -> String: return String(value)
def main():
    _ = pipeline(Result[Int,String](Ok(1))).raising[Int]().ensure(predicate,factory)
