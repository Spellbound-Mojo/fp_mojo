# error: no matching method in call to 'ensure'
from fp.algebra import ResultFamily
from fp.functions import pipeline
from fp.data import Result, Ok
def predicate(value: Int) -> Bool: return False
def factory(var value: Int) -> String: return "bad"
def main(): _ = pipeline[ResultFamily[String]](Result[Int, String](Ok(1))).ensure(predicate, factory)
