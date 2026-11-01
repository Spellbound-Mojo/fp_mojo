# error: use of uninitialized value
from fp.iteration import iterated
def main():
    var source = iterated(List[Optional[Int]]([Optional(1)]))
    _ = source^.sequence()
    _ = source^.sequence()
