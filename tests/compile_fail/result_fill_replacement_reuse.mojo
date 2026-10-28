# error: use of uninitialized value
from fp.data import Result, Ok

def main():
    var replacement: List[Int] = [7]
    _ = Result[Int, Int](Ok(1)).fill(replacement^)
    print(len(replacement))
