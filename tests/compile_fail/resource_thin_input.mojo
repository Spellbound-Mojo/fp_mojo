# error: no matching
from fp.effects import IO, lift_resource, pure_resource
def bad(value: String) -> IO[Int].Pure[Int]: return IO[Int].pure(1)
def main():
    var pointer: def(String) thin -> IO[Int].Pure[Int] = bad
    _ = lift_resource(pure_resource[Int](7)).use(pointer)
