# error: no matching
from fp.functions import pipeline
def mutate(mut value: Int) -> Optional[Int]:
    value += 1
    return Optional(value)
def main():
    var callback: def(mut Int) thin -> Optional[Int] = mutate
    _ = pipeline(List[Int]([1])).traverse(callback)
