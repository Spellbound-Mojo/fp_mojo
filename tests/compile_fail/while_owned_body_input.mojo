# error: while loop: the body must repeatedly take and return the carry
from fp.control import while_loop
from while_predicate_support import Predicate,Body,Bare,Once,Both
from fp.callables import UnaryContract,MutableUnary,OnceUnary,mut_ref
@fieldwise_init
struct Invalid(MutableUnary):
    comptime Arg=String
    comptime Out=Int
    def call_mut(mut self,var value:Self.Arg)->Self.Out: return 0
def main() raises:
    try: _=while_loop(Predicate(False,0),Invalid(),0)
    except: pass
