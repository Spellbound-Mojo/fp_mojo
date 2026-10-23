# error: List combination copies each element into every pair
from fp.functions import piped
@fieldwise_init
struct FCResource(Movable):
    var value: Int
def main():
    var left = List[FCResource]()
    left.append(FCResource(1))
    var right: List[Int] = [2]
    _ = piped(left^).product(right^)
