# error: cannot implicitly convert
# error: origin_of(local)
from fp.callables import BinarySignature
def wrong[o: ImmOrigin](ref[o] owner: List[Int]) -> Span[Int, o]:
    var local: List[Int] = [1]
    var view = Span(local)
    comptime View = type_of(view)
    def choose(var first: View, var second: View) {ref owner} -> View:
        _ = len(owner)
        _ = second
        return first
    return BinarySignature[View, View, View].capture(choose)(view, view)
def main(): pass
