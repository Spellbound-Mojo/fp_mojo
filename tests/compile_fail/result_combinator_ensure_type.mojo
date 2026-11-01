# error: constraint
from fp.data import Result, Ok
def predicate(value: Int) -> Int: return value
def problem(value: Int) -> String: return String(value)
def main():
    _ = Result[Int, String](Ok(1)).ensure(predicate, problem)
