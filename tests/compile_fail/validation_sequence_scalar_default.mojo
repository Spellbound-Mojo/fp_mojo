# error: constraint
from fp.data import Result, Ok
from fp.iteration import iterated

def main():
    var values: List[Result[Int,String]] = [Result[Int,String](Ok(1))]
    _ = iterated(values^).par_sequence()
