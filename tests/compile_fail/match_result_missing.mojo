# error: fp.match: constructor Err has no clause that cannot decline
import fp
from fp.data import Ok, Err, Result

def main():
    var r: Result[Int, String] = Ok(1)
    _ = fp.match(r, lambda (o: Ok[Int]) -> Int: o.value)
