# error: use of uninitialized value 'predicate'
from fp.control import while_loop
from while_predicate_support import Predicate,Body,Bare,Once,Both
from fp.callables import UnaryContract,MutableUnary,OnceUnary,mut_ref
def main():
    var predicate=Predicate(False,0)
    _=while_loop(predicate^,Body(0),0)
    _=predicate.calls
