# error: invalid call to 'copy'
from fp.callables import BorrowSignature
@fieldwise_init
struct Token(Movable):
    var value: Int
def main():
    var token = Token(1)
    def below(value: Int) {var token^} -> Bool: return value < token.value
    var callback = BorrowSignature[Int, Bool].capture(below^)
    _ = callback.copy()
