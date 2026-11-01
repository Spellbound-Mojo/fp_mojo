# error: eval_on: `Fiber` is tied to the root that made it
from fp.effects.async_runtime import IO, Fiber, BlockingPool


def escape(pool: BlockingPool) -> IO[Fiber[Int, Int], Int]:
    # The handle names a fiber of the region's root, which ends with the region.
    return IO[Int, Int].pure(1).start().eval_on(pool)


def main():
    try:
        _ = escape(BlockingPool())
    except:
        pass
