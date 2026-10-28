# error: while loop: the predicate must have a repeatable receiver
from fp.control import while_loop
from while_predicate_support import Predicate,Body,Bare,Once,Both
from fp.callables import UnaryContract,MutableUnary,OnceUnary,mut_ref
def main() raises:
    try: _=while_loop(Bare(),Body(0),0)
    except: pass
