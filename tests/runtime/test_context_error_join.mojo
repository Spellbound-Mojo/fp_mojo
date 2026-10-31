from fp.functions import pipeline
from std.testing import assert_equal
@fieldwise_init
struct Fault(Movable):
    var code: Int
def select(value: Int) raises Fault -> Bool: return value > 1
def transform(var value: Int) raises Fault -> Int:
    if value == 3: raise Fault(33)
    return value * 2
def parse(var text: String) raises Fault -> Int:
    if text == "": raise Fault(1)
    return text.byte_length()
def total(var acc: Int, var value: Int) raises Fault -> Int:
    if value < 0: raise Fault(-value)
    return acc + value
def checked() raises Fault -> List[Int]:
    var offset = 10
    def shift(var value: Int) raises Fault {imm offset} -> Int:
        if value > 100: raise Fault(100)
        return value + offset
    var out = List[Int]()
    out.append(pipeline(List[Int]([1, 2])).filter(select).map(transform).get()[0])
    # Later native closures see the joined error.
    out.append(pipeline(String("abc")).then(parse).then(shift).get())
    var code = 0
    try: _ = pipeline(String("")).then(parse).then(shift).get()
    except error: code = error.code
    out.append(code)
    # Terminal folds accept a thin raising step directly.
    out.append(pipeline(List[Int]([1, 2, 3])).fold_left(total, 0).get())
    # A selected error still governs: the same error joins.
    out.append(pipeline(String("ab")).raising[Fault]().then(parse).get())
    return out^
def main() raises:
    # A thin raising stage selects the native error; no raising[E]() needed.
    var code = 0
    try: _ = pipeline(List[Int]([1, 2, 3])).filter(select).map(transform).get()
    except error: code = error.code
    assert_equal(code, 33)
    code = 0
    try: _ = pipeline(List[Int]([1, -4])).fold_left(total, 0).get()
    except error: code = error.code
    assert_equal(code, 4)
    var results: List[Int]
    try: results = checked()
    except error: raise Error("unexpected fault ", error.code)
    assert_equal(results, List[Int]([4, 13, 1, 6, 2]))
