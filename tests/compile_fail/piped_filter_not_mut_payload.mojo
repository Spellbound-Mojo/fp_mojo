# error: no matching method in call to 'filter_not'
from fp.functions import pipeline

def select(mut x: Int) -> Bool: return x > 0
def main():
    var xs: List[Int] = [1, 2]
    _ = pipeline(xs^).filter_not(select).get()
