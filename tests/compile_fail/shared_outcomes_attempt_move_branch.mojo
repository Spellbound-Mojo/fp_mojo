# error: repeatable
from fp.algebra import ListFamily
from fp.effects import ResultT
from fp.functions import pipeline
from fp.data import Result, Ok
@fieldwise_init
struct Uncopyable(Movable):
    var value: Int
def inspect(value: Result[Uncopyable, String]) -> List[Result[Int, String]]:
    return [Result[Int, String](Ok(0))]
def main():
    var values: List[Result[Uncopyable, String]] = [Result[Uncopyable, String](Ok(Uncopyable(1)))]
    _ = pipeline[ResultT[ListFamily, String]](values^).attempt_tap(inspect)
