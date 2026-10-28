# error: while loop: the predicate must read the carry
from fp.control import while_loop
from while_predicate_support import Predicate,Body,Bare,Once,Both
from fp.callables import UnaryContract,MutableUnary,OnceUnary,mut_ref
def main() raises:
    try: _=while_loop(Predicate[Bool,Never,String](False,0),Body(0),0)
    except: pass
