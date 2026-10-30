# error: no matching function in call to 'traverse'
from context_reader_run_support import Produce, Once, Length
from fp.effects import Reader, run
from fp.algebra import ListFamily, traverse, map

def main():
    _ = traverse[ListFamily, Reader[Int]](List[Int]([1, 2]), Once())
