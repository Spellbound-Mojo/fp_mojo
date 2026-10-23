# error: no matching method in call to 'filter'
from fp.functions import piped

def select(x: Int) -> Bool: return x > 0
def main():
    var xs = range(3)
    _ = piped(xs^).filter(select).get()
