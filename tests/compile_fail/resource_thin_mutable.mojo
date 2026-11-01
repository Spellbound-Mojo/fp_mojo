# error: no matching
from fp.effects import IO, lift_resource, pure_resource
def bad(mut value: Int) -> IO[Int].Pure[Int]:
    value += 1
    return IO[Int].pure(value)
def main():
    var pointer: def(mut Int) thin -> IO[Int].Pure[Int] = bad
    _ = lift_resource(pure_resource[Int](7)).eval_map(pointer)
