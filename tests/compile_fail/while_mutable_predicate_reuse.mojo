# error: use of uninitialized value 'predicate'
from fp.control import while_loop_mut
from fp.callables import mut_ref
from while_predicate_support import Predicate, Body, Bare, Once, Both
def main():
    var body = Body(0)
    var predicate = Predicate(False,0)
    _ = while_loop_mut(predicate^,body,0)
    print(predicate.calls)
