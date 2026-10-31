# error: invalid call to 'product_n': violated constraint
# A deferred family's combination is not a pure carrier, so its result type
# is described step by step for at most eight operands.
from fp.functions import pipeline
from fp.effects import Reader, ask
def main() raises:
    comptime R = Reader[Int]
    _ = pipeline(ask[R]()).product_n((ask[R](), ask[R](), ask[R](), ask[R](), ask[R](), ask[R](), ask[R](), ask[R]())).get()
