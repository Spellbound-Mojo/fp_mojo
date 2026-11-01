# error: use of uninitialized value
from fp.functions import pipeline
def main():
    var source = List[Optional[Int]]([Optional(1)])
    _ = pipeline(source^).sequence()
    _ = source^
