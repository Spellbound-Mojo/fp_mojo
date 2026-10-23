# error: no matching method
from fp.algebra import ResultFamily
from fp.functions import piped
from fp.data import Result, Ok
def predicate(value: Int) -> Int: return 1
def factory(value: Int) -> String: return "bad"
def main(): _ = piped(Result[Int, String](Ok(1))).ensure[ResultFamily[String]](predicate, factory)
