# Mojo 1.2: bind F before checking the invalid native signature.
# Removing this hint reproduces a compiler crash; see native-boundaries.md.
# error: value passed to 'F' cannot be converted
# error: no matching method
from fp.functions import piped
def add(a:Int,b:Int,c:Int) -> Int: return a+b+c
def main(): _=piped(Optional(1)).map_n[F=type_of(add)]((Optional(2),),add)
