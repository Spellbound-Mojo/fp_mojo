# error: run: computation belongs to a different effect family
from fp.algebra import pure, flat_map, ResultFamily
from fp.effects import StateT, run
from fp.callables import as_unary

comptime Expected=StateT[ResultFamily[Int],Int]
comptime Wrong=StateT[ResultFamily[String],Int]

def wrong(var value:Int)->type_of(pure[Wrong](Int())):
    return pure[Wrong](value)

def main():
    _=run[Expected](flat_map[Expected](as_unary(wrong),pure[Expected](1)),0)
