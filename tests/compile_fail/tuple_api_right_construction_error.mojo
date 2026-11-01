# error: cannot call function that may raise
from algebra_support.tuple_contracts import attached_right
from algebra_support.fill_contracts import Failing
def main():
    _ = attached_right[Failing](17, 3)
