# error: constraint
from fp.data import Result, Err
def recover(var error: String) -> String: return error^
def main():
    _ = Result[Int, String](Err(String("error"))).recover(recover)
