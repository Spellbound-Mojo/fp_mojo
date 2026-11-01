# error: constraint
from fp.data import Result, Err
def predicate(error: String) -> Bool: return True
def recover(var error: String) -> String: return error^
def main():
    _ = Result[Int, String](Err(String("retry"))).recover_if(predicate, recover)
