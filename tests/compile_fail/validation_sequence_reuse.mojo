# error: use of uninitialized
from fp.data import Result, Ok
from fp.iteration import iterated

def main():
    var values: List[Result[Int,List[String]]] = [Result[Int,List[String]](Ok(1))]
    var source = iterated(values^)
    _ = source^.par_sequence()
    _ = source^.par_sequence()
