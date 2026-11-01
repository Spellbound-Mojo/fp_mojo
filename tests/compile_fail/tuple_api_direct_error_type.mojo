# error: cannot implicitly convert
from fp.data import Result, Err
def wrong() -> Result[Tuple[Int, Int], String]:
    return Result[Int, Int](Err(7)).tuple_right(3)
def main():
    _ = wrong()
