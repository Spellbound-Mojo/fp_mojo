# error: missing required argument: 'buffer'
from fp.iteration import iterated
def main():
    var pairs: List[Tuple[Int,Int]] = [(1,2)]
    _ = iterated(pairs^).unzip()
