# error: no matching method in call to 'filter'
from fp.functions import pipeline

def select(x: Int) -> Bool: return x > 0
def main():
    var xs = range(3)
    _ = pipeline(xs^).filter(select).get()
