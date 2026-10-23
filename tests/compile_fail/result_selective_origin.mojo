# error: constraint
from fp.data import Result, Err
def mismatch(left: List[Int], right: List[Int]):
    var value = Result[Span[Int, origin_of(left)], String](Err(String("retry")))
    var view = Span(right)
    def predicate(error: String) -> Bool: return True
    def recover(var error: String) {view} -> Span[Int, origin_of(right)]: return view
    _ = value^.recover_if(predicate, recover)
def main(): mismatch([1], [2])
