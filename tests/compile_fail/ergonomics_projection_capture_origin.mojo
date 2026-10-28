# error: cannot implicitly convert
# error: origin_of(local)
from fp.effects import Reader, asks, run

def wrong[o: ImmOrigin](ref[o] owner: List[Int]) -> Span[Int, o]:
    var local: List[Int] = [1]
    def projection(value: Int) {imm local} -> Span[Int, ImmOrigin(origin_of(local))]:
        return Span(local)
    var program = asks[Reader[Int]](projection)
    var environment = 1
    return run[Reader[Int]](program^, environment)

def main(): pass
