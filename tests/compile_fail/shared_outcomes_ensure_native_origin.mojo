# error: constraint
from fp.algebra import ResultFamily
from fp.functions import piped
from fp.data import Result, Ok
def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int, origin_of(left)]
    comptime R = Span[Int, origin_of(right)]
    def predicate(value: Int) raises L -> Bool: return True
    def factory(value: Int) raises R -> String: return "bad"
    try:
        _ = piped(Result[Int, String](Ok(1))).ensure[ResultFamily[String]](predicate, factory)
    except error: pass
def main(): bad([1], [2])
