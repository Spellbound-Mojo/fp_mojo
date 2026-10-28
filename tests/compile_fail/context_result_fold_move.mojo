# error: use of uninitialized value
from fp.data import ok
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily

def same(var value: Int) -> Int: return value
def main():
    var handler = kleisli[IdentityFamily](same)
    _ = pipeline(ok[Int](1)).fold_owned(handler^, same)
    _ = pipeline(ok[Int](2)).fold_owned(handler, same)
