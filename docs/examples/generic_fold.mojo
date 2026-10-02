"""The same sequential fold over scalar, SIMD and a user-defined document."""
from fp.iteration import fold_left
from std.iter import iter
from std.testing import assert_equal

def scalar(var total: Int, var value: Int) -> Int: return total + value
def vector[dtype: DType, width: Int](var total: SIMD[dtype, width],
                                   var value: SIMD[dtype, width]) -> SIMD[dtype, width]:
    return total + value

@fieldwise_init
struct Document(Movable):
    var text: String
    var words: Int

def append_word(var document: Document, var word: String) -> Document:
    if document.words: document.text += " "
    document.text += word
    document.words += 1
    return document^

def vectors[dtype: DType, width: Int]() raises:
    comptime V = SIMD[dtype, width]
    var first = V(0)
    var second = V(0)
    comptime for lane in range(width):
        first[lane] = Scalar[dtype](lane + 1)
        second[lane] = Scalar[dtype](10 + lane)
    var inputs: List[V] = [first, second]
    var expected = V(0)
    for value in inputs: expected += value
    var actual = fold_left(vector[dtype, width], V(0), iter(inputs))
    comptime assert type_of(actual) == V
    assert_equal(actual, expected)
    assert_equal(actual.reduce_add(), Scalar[dtype](11 * width + width * (width - 1)))
    assert_equal(fold_left(vector[dtype, width], first, List[V]()), first)

def main() raises:
    var numbers: List[Int] = [1, 2, 3]
    var expected = 0
    for value in numbers: expected += value
    assert_equal(fold_left(scalar, 0, iter(numbers)), expected)
    assert_equal(fold_left(scalar, 7, List[Int]()), 7)
    vectors[DType.int32, 4]()
    vectors[DType.float64, 2]()
    var words: List[String] = ["native", "functional", "composition"]
    var native = Document(String(), 0)
    for word in words: native = append_word(native^, word)
    var document = fold_left(append_word, Document(String(), 0), words^)
    assert_equal(document.text, native.text)
    assert_equal(document.words, native.words)
    var empty = fold_left(append_word, document^, List[String]())
    assert_equal(empty.text, "native functional composition")
    assert_equal(empty.words, 3)
    print("scalar=", expected, "; document=", empty.text)
