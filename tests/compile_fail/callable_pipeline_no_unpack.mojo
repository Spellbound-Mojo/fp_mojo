# Mojo 1.2: bind F before checking the invalid native signature.
# Removing this hint reproduces a compiler crash; see native-boundaries.md.
# error: value passed to 'F' cannot be converted
# error: no matching function in call to 'as_unary'
from fp.functions import pipe, as_unary
from std.builtin.variadics import TypeList
def split(a: Int, b: String) -> Int: return a + b.byte_length()
def main():
    var a = as_unary[F=type_of(split)](split)
    comptime Path = TypeList.of[Trait=Movable & Deinitable, Int]()
    _ = pipe[Path]((1, String("x")), a)
