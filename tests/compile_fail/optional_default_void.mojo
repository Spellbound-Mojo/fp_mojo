# error: no matching
from fp.functions import pipeline

def empty(): pass

def main():
    _ = pipeline(Optional[NoneType]()).get_or_else(empty)
