# error: cannot call function that may raise
from algebra_support.fill_contracts import discarded,Failing
def main():
    _=discarded[Failing](17)
