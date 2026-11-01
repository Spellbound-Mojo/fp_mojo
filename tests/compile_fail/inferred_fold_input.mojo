# error: no matching
from fp.functions import pipeline
def step(var a: String, var b: Int) -> Optional[Int]: return Optional(b)
def main() raises:
    _ = pipeline(List[Int]([1])).fold_effect(0).run(step)
