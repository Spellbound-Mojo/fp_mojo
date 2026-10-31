# error: invalid call to 'product': violated constraint
from fp.functions import piped
@fieldwise_init
struct FCResource(Movable):
    var value: Int
def main():
    var left = List[FCResource]()
    left.append(FCResource(1))
    var right: List[Int] = [2]
    _ = piped(left^).product(right^)
