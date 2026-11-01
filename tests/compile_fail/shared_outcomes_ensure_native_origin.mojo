# error: constraint
from fp.algebra import ResultFamily
from fp.functions import pipeline
from fp.data import Result, Ok
def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int, origin_of(left)]
    comptime R = Span[Int, origin_of(right)]
    def predicate(value: Int) raises L -> Bool: return True
    def factory(value: Int) raises R -> String: return "bad"
    try:
        _ = pipeline[ResultFamily[String]](Result[Int, String](Ok(1))).ensure(predicate, factory)
    except error: pass
def main(): bad([1], [2])
