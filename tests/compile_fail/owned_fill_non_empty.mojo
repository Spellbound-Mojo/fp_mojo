# error: invalid call to 'fill'
from fp.data import NonEmptyList
from fp.functions import pipeline
from owned_fill_support import Box
def main():
    _=pipeline(NonEmptyList(1)).fill(Box(1))
