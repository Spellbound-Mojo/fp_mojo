# error: aliasing values passed mutably
from fp.data import Result, Ok
def main():
    var calls = 0
    def predicate(value: Int) {mut calls} -> Bool:
        calls += 1
        return False
    def problem(value: Int) {mut calls} -> String:
        calls += 1
        return "rejected"
    _ = Result[Int, String](Ok(1)).ensure(predicate, problem)
