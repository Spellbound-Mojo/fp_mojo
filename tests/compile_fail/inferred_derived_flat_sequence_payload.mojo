# error: violated constraint
from fp.functions import pipeline
def main() raises:
    _ = pipeline(List[Optional[Int]]([Optional(1)])).flat_sequence()
