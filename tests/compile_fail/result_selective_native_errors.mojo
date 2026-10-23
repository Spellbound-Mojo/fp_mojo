# error: Result conditional: incompatible native errors
from fp.data import Result, Err
def predicate(error: String) raises Int -> Bool: raise 1
def recover(var error: String) raises String -> Int: raise error^
def main():
    try: _ = Result[Int, String](Err(String("retry"))).recover_if(predicate, recover)
    except error: pass
