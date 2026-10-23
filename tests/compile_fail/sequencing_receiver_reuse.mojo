# error: uninitialized
from fp.functions import piped
def make() -> Optional[Int]: return Optional(1)
def main():
    var source = piped(Optional(1))
    _ = source^.before(make)
    _ = source^.followed_by(make)
