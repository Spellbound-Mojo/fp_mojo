# error: no matching method in call to 'filter'
from fp.functions import piped

def select(mut x: Int) -> Bool: return x > 0
def main():
    var xs: List[Int] = [1, 2]
    _ = piped(xs^).filter(select).get()
