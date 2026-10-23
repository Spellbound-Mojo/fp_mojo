# error: constraint
from fp.algebra import ListMonoid
from fp.functions import piped

def main():
    _ = piped(List[Int]([1,2])).par_sequence[ListMonoid[String]]()
