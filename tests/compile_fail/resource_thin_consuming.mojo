# error: no matching
from fp.effects import IO, lift_resource, pure_resource
def bad(var value: String) -> IO[Int].Pure[Int]: return IO[Int].pure(value.byte_length())
def main():
    var pointer: def(var String) thin -> IO[Int].Pure[Int] = bad
    _ = lift_resource(pure_resource[Int](String("owned"))).eval_tap(pointer)
