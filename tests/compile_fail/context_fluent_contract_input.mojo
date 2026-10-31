# error: invalid call to 'mapped': violated constraint
from fp.algebra import Functor, ListFamily
from fp.algebra.contracts import MapContract
from fp.callables import UnaryContract
from fp.functions import Pipeline, pipeline, Identity

def mapped[I: Functor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var value: V, var function: F) raises MapContract[I,V,F].Error -> Pipeline[MapContract[I,V,F].Family, MapContract[I,V,F].Out] where MapContract[I,V,F].Compatible:
    return pipeline[I](value^).map(function^)

def main():
    _ = mapped[ListFamily](List[String](["wrong"]), Identity[Int]())
