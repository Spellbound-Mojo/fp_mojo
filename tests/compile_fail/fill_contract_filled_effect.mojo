# error: cannot call function that may raise
from algebra_support.fill_contracts import filled,Failing
def main():
    _=filled[Failing](17,3)
