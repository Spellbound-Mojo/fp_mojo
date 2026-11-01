# error: violated constraint
from fp.effects import IO, pure_resource, eval_resource
from fp.algebra import pure

def inner(value: Int) -> type_of(eval_resource(pure[IO[Int]](0))):
    return eval_resource(pure[IO[Int]](value))

def main():
    _ = pure_resource[Int](1).flat_map(inner)
