# error: constraint
from fp.algebra import ListMonoid
from fp.functions import pipeline

def main():
    _ = pipeline(List[Int]([1,2])).par_sequence[ListMonoid[String]]()
