# error: no matching method
from fp.functions import pipeline
def bad(value: Int) -> List[Int]: return List[Int]([value])
def main(): _ = pipeline(range(3)).max_by(bad).get()
