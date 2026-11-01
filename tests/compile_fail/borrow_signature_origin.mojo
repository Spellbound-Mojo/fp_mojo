# error: cannot implicitly convert
from fp.callables import BorrowSignature
def wrong[o: ImmOrigin](ref[o] owner: List[Int]) -> Span[Int, o]:
    var local: List[Int] = [1]
    var view = Span(local)
    comptime View = type_of(view)
    def project(value: Int) {view} -> View: return view
    var value = 0
    return BorrowSignature[Int, View].capture(project).invoke(value)
def main(): pass
