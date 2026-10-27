# error: no matching
from fp.functions import pipeline
def step(var a: Int, var b: Int) -> Optional[Int]: return Optional(a + b)
def main() raises:
    _ = pipeline(3).fold_effect(0).run(step)
