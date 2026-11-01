# error: no matching
from fp.effects import IO, lift_resource, pure_resource
from fp.algebra import pure
def bad(value: Int) -> IO[String].Pure[Int]: return pure[IO[String]](value)
def main(): _ = lift_resource(pure_resource[Int](7)).eval_tap(bad)
