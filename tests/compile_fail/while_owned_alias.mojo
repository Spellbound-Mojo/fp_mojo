# error: aliasing
from fp.control import while_loop
from while_predicate_support import Predicate,Body,Bare,Once,Both
from fp.callables import UnaryContract,MutableUnary,OnceUnary,mut_ref
def main():
    var state=Both(0)
    _=while_loop(mut_ref(state),mut_ref(state),0)
