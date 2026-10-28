# error: no matching function in call to 'untupled'
from fp.functions import untupled
def main():
    var offset = 7
    def captured(var pair: Tuple[Int, Int]) {offset} -> Int: return pair[0] + offset
    _ = untupled(captured)
