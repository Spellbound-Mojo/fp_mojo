# error: use of uninitialized value
from fp.iteration import iterated
def callback(var value: Int) -> Optional[Int]: return Optional(value)
def main():
    var source = iterated(range(2))
    _ = source^.traverse(callback)
    _ = source^.to_list()
