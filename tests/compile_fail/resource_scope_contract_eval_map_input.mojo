# error: no matching
from fp.effects import IO, lift_resource, pure_resource
from fp.algebra import pure
def bad(value: String) -> IO[Int].Pure[Int]: return pure[IO[Int]](1)
def main(): _ = lift_resource(pure_resource[Int](7)).eval_map(bad)
