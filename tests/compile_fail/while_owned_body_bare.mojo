# error: while loop: the body must repeatedly take and return the carry
from fp.control import while_loop
from while_predicate_support import Predicate,Body,Bare,Once,Both
from fp.callables import UnaryContract,MutableUnary,OnceUnary,mut_ref
@fieldwise_init
struct Invalid(UnaryContract, Movable):
    comptime Arg=Int
    comptime Out=Int
def main() raises:
    try: _=while_loop(Predicate(False,0),Invalid(),0)
    except: pass
