# error: violated constraint
from fp.effects import IO, eval_resource
from fp.algebra import pure

def use(value: Int) -> IO[String].Pure[Int]:
    return pure[IO[String]](value)

def main():
    _ = eval_resource(pure[IO[Int]](1)).use(use)
