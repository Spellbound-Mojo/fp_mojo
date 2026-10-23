# error: constraint
from fp.data import Result, Err
from fp.functions import piped
def predicate(error: String) -> Bool: return True
def recover(var error: String) -> Result[Int, Int]: return Err(1)
def main():
    _ = piped(Result[Int, String](Err(String("retry")))).or_else_if(predicate, recover)
