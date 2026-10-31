# error: origin
from fp.data import Result, Ok
from fp.functions import pipeline
def invalid[origin: ImmOrigin](ref[origin] external: List[Int]) -> Result[Tuple[Span[Int, origin], Int], String]:
    var local: List[Int] = [1]
    return pipeline(Result[Span[Int, origin_of(local)], String](Ok(Span(local)))).product(Result[Int, String](Ok(2))).get()
def main(): pass
