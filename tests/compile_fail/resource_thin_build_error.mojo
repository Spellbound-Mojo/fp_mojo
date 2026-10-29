# error: no matching
from fp.effects import IO, lift_resource, pure_resource
def bad(value: Int) raises String -> IO[Int].Pure[Int]: raise String("wrong")
def main():
    var pointer: def(Int) raises String thin -> IO[Int].Pure[Int] = bad
    _ = lift_resource(pure_resource[Int](7)).use(pointer)
