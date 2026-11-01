# error: use of uninitialized value
from fp.functions import pipeline
def step(var a: Int, var b: Int) -> Optional[Int]: return Optional(a + b)
def main():
    var stage = pipeline(List[Int]([1])).fold_effect(0)
    _ = stage^.run(step)
    _ = stage^
