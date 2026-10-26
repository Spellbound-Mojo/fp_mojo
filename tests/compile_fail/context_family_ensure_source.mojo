# error: no matching method in call to 'ensure'
from fp.functions import pipeline
from fp.data import Result, Ok
from fp.algebra import ResultFamily
def predicate(value: Int) -> Bool: return False
def factory(value: Int) -> String: return String(value)
def main():
    _ = pipeline[ResultFamily[String]](Result[Int,Int](Ok(1))).ensure(predicate,factory)
