# error: use of uninitialized value 'body'
from fp.control import while_loop
from while_predicate_support import Predicate,Body,Bare,Once,Both
from fp.callables import UnaryContract,MutableUnary,OnceUnary,mut_ref
def main():
    var body=Body(0)
    _=while_loop(Predicate(False,0),body^,0)
    _=body.calls
