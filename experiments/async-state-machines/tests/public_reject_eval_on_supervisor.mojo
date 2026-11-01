# error: eval_on: `Held` reaches `Supervisor` in `Optional` in a field of `Held`, which is tied to the root that made it
from fp.effects.async_runtime import IO, Supervisor, BlockingPool


struct Held(Movable):
    """A result that carries a supervisor out of its region, inside a field."""
    var supervisor: Optional[Supervisor[Int]]

    def __init__(out self):
        self.supervisor = None


def escape(pool: BlockingPool) -> IO[Held, Int]:
    return IO[Held, Int].pure(Held()).eval_on(pool)


def main():
    try:
        _ = escape(BlockingPool())
    except:
        pass
