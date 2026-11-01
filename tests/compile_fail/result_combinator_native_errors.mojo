# error: Result conditional: incompatible native errors
from fp.data import Result, Ok
def predicate(value: Int) raises Int -> Bool: raise value
def problem(value: Int) raises String -> String: raise String(value)
def main():
    try: _ = Result[Int, String](Ok(1)).ensure(predicate, problem)
    except error: pass
