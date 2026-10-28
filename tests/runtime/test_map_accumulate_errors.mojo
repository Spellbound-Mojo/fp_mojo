from fp.iteration import map_accumulate, iterated
from std.testing import assert_equal

def no_error(var a: Int, var t: Int) raises Never -> Tuple[Int,String]: return (a+t, String(t))
def failure(var a: Int, var t: Int) raises Int -> Tuple[Int,String]: raise a+t
comptime NeverPointer = def(var Int, var Int) raises Never thin -> Tuple[Int,String]
comptime ErrorPointer = def(var Int, var Int) raises Int thin -> Tuple[Int,String]
def main() raises:
    var never: NeverPointer = no_error
    var result = map_accumulate[Y=String](never, 0, [1,2])
    assert_equal(result[0], 3)
    assert_equal(result[1], ["1","2"])
    var pointer: ErrorPointer = failure
    var observed = 0
    try: _ = map_accumulate[Y=String,E=Int](pointer, 10, [2])
    except error:
        comptime assert type_of(error) == Int
        observed = error
    assert_equal(observed, 12)
    try: _ = map_accumulate(failure, 20, [3])
    except error: observed = error
    assert_equal(observed, 23)
