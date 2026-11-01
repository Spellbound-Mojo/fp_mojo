# error: constraint
from fp.algebra import ResultFamily, ListFamily, fail
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from fp.effects import ResultT
def restore(var error: String) -> Int: return 1
def main():
    comptime F = ResultT[ListFamily, String]
    var source = List[Result[Int, Int]]([Result[Int, Int](Err(1))])
    _ = pipeline[F](source^).recover(restore).get()
