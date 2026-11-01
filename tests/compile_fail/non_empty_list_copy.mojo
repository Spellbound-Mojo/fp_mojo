# error: Copyable
from fp.data import NonEmptyList
@fieldwise_init
struct NELMoveOnly(Movable):
    var value: Int
def main():
    var values = NonEmptyList(NELMoveOnly(1))
    _ = values.copy()
