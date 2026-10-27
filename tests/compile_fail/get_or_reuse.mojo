# error: use of uninitialized value
from fp.functions import pipeline
def main():
    var fallback: List[Int] = [1, 2]
    _ = pipeline(Optional[List[Int]]()).get_or(fallback^)
    _ = fallback^
