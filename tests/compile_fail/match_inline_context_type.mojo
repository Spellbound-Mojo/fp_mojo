# error: fp.match: clause 1 takes String as its second parameter; the context is
import fp
from fp.data import Ok, Err, Result

def main():
    var r: Result[Int, Int] = Ok(1)
    _ = fp.match(r,
        lambda (o: Ok[Int], k: Int) -> Int: o.value * k,
        lambda (e: Err[Int], k: String) -> Int: e.value,
        context=2)
