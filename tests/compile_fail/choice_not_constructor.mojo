# error: is not a constructor of
from fp.adt import Value, Cases, Choice, Data

@fieldwise_init
struct Red(Copyable):
    pass

@fieldwise_init
struct Green(Copyable):
    var shade: Int

struct Light(Data):
    comptime Layer[R: Value] = Cases[Red, Green]

def main():
    var c = Choice[Light](String("blue"))
    _ = c^
