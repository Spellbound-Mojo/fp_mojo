# error: aliasing values
from fp.data import Ior, Right
from fp.algebra import map, IorFamily, StringMonoid
from fp.functions import Identity
def main():
    var values = List[Int]([1, 2])
    var view = Span(values)
    comptime View = type_of(view)
    var source = Ior[String, View](Right(view))
    _ = map[IorFamily[StringMonoid]](Identity[View](), source^)
