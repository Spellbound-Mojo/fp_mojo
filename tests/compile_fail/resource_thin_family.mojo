# error: no matching
from fp.effects import IO, lift_resource, pure_resource
def bad(value: Int) -> IO[String].Pure[Int]: return IO[String].pure(value)
def main():
    var pointer: def(Int) thin -> IO[String].Pure[Int] = bad
    _ = lift_resource(pure_resource[Int](7)).eval_tap(pointer)
