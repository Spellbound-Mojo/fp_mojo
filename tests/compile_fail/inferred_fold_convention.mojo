# error: no matching
from fp.functions import pipeline
def step(mut a: Int, var b: Int) -> Optional[Int]:
    a += b
    return Optional(a)
def main() raises:
    var pointer: def(mut Int, var Int) thin -> Optional[Int] = step
    _ = pipeline(List[Int]([1])).fold_effect(0).run(pointer)
