# error: flat_map: Optional callback required
from fp.algebra import flat_map, OptionalFamily
from fp.callables import as_unary

def wrong_family(var value:Int)->List[Int]:
    return [value]

def main():
    _=flat_map[OptionalFamily](as_unary(wrong_family),Optional(1))
