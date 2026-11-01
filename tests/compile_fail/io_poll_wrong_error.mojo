# error: violated constraint
from fp.effects import IO, Poll
from fp.algebra import pure

def wrong(poll: Poll[Int]):
    _ = poll.apply(pure[IO[String]](1))

def main():
    pass
