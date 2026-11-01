# error: invalid call to 'tuple_left'
from fp.data import NonEmptyList
from fp.functions import pipeline
from owned_fill_support import Box
def main():
    _=pipeline(NonEmptyList(1)).tuple_left(Box(1))
