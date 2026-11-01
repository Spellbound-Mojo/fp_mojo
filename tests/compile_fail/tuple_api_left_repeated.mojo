# error: violated constraint
from algebra_support.tuple_contracts import attached_left
from fp.algebra import ListFamily
from owned_fill_support import Box
def main():
    _ = attached_left[ListFamily](List[Int](), Box(1))
