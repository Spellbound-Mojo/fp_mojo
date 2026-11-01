# error: constraint
from fp.iteration import iterated, Unbounded
def main(): _ = iterated(range(3)).unzip[Int,Int](buffer=Unbounded())
