# error: constraint
from fp.functions import pipeline
from fp.algebra import IdentityFamily
def main(): _=pipeline[IdentityFamily](1).product_n((2,3,4,5,6,7,8,9))
