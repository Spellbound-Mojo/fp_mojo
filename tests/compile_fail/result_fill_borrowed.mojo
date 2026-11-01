# error: cannot transfer
from fp.data import Result, Ok

def wrong(source: Result[List[Int], Int]):
    _ = source^.fill(7)

def main():
    var source = Result[List[Int], Int](Ok(List[Int]([1])))
    wrong(source)
