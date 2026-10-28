# error: while loop: incompatible errors
from fp.control import while_loop
from while_predicate_support import Predicate,Body,Bare,Once,Both
from fp.callables import UnaryContract,MutableUnary,OnceUnary,mut_ref
def main() raises:
    try: _=while_loop[Int](Predicate(False,0),Body(0),0)
    except: pass
