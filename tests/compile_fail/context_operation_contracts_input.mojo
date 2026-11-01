# error: invalid call to 'forward': violated constraint
from fp.algebra import Functor, ListFamily
from fp.algebra.contracts import MapContract
from fp.callables import UnaryContract
from fp.functions import pipeline, Identity
def forward[I: Functor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var value: V, var function: F
) raises MapContract[I, V, F].Error -> MapContract[I, V, F].Out where MapContract[I, V, F].Compatible:
    return pipeline[I](value^).map(function^).get()
def main():
    _ = forward[ListFamily](List[Int]([1]), Identity[String]())
