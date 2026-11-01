# error: constraint failed: while loop: incompatible errors
from fp.control import while_loop_mut
from fp.callables import mut_ref
from while_predicate_support import Predicate, Body, Bare, Once, Both
def main() raises:
    var body = Body(0)
    _ = while_loop_mut[E=Error](Predicate(False,0),body,0)
