# error: invalid call to 'copy': violated constraint
from fp.data import Result, Ok

@fieldwise_init
struct Token(Movable):
    var value: Int

def main():
    var value = Result[Token, Int](Ok(Token(3)))
    var duplicate = value.copy()
    print(duplicate.is_ok())
