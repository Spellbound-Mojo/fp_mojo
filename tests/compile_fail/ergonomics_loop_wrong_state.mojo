# error: no matching
from fp.algebra import IdentityFamily, tail_rec_m
from fp.data import ControlFlow, Break
def wrong(var a: Int) -> ControlFlow[Int,String]: return Break(a)
def main(): _ = tail_rec_m[IdentityFamily](wrong, 1)
