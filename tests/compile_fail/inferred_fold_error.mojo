# error: no matching
from fp.functions import pipeline
def step(var a: Int, var b: Int) raises Int -> Optional[Int]: raise b
def main() raises:
    _ = pipeline(List[Int]([1])).fold_effect(0).run(step)
