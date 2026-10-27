# error: no matching
from fp.functions import pipeline
def factory() raises String -> Int: raise String("wrong")
def main():
    _ = pipeline(Optional[Int]()).raising[Int]().get_or_else(factory)
