# error: no matching
from fp.functions import pipeline
def factory() -> String: return String("bad")
def main():
    _ = pipeline(Optional[Int]()).get_or_else(factory)
