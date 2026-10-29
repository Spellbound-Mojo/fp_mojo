# error: invalid call to 'product_l': violated constraint
from fp.algebra import product_l, OptionalFamily
def main(): _ = product_l[OptionalFamily](Optional(1),List[Int]([2]))
