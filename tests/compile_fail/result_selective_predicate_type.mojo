# error: constraint
from fp.data import Result, Err
def predicate(error: String) -> Int: return 1
def recover(var error: String) -> Int: return 0
def main():
    _ = Result[Int, String](Err(String("retry"))).recover_if(predicate, recover)
