# error: origin_of(local)
from fp.iteration import align, pad_zip
from std.iter import iter

def check(anchor: List[Int]):
    var local: List[Int] = [1,2]
    var expected=align(range(3),iter(anchor))
    var actual=align(range(3),iter(local))
    expected=actual^
    var expected_pad=pad_zip(iter(anchor),range(3))
    var actual_pad=pad_zip(iter(local),range(3))
    expected_pad=actual_pad^
def main():
    var anchor: List[Int] = [1,2]
    check(anchor)
