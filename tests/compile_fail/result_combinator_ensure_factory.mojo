# error: constraint
from fp.data import Result, Ok
def predicate(value: Int) -> Bool: return value > 0
def problem(value: Int) -> Int: return value
def main():
    _ = Result[Int, String](Ok(1)).ensure(predicate, problem)
