# error: static_length must be nonnegative or omitted
from fp.control import scan
def body(var x: Int, var y: Tuple[]) -> Tuple[Int, Int]: return (x + 1, x)
def main() raises:
    _ = scan[static_length=-2](body, 0, length=3)
