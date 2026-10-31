# error: no matching method in call to 'filter'
from fp.functions import pipeline

def select(x: Int) -> Int: return x
def main():
    var xs: List[Int] = [1, 2]
    _ = pipeline(xs^).filter(select).get()
