# error: no matching method in call to 'ensure'
from fp.functions import pipeline
from fp.data import Result, Ok
from fp.algebra import ResultFamily
from fp.algebra import ValidationFamily, StringMonoid
def predicate(value: Int) -> Bool: return False
def factory(value: Int) -> String: return String(value)
def main():
    _ = pipeline[ValidationFamily[StringMonoid]](Result[Int,String](Ok(1))).ensure(predicate,factory)
