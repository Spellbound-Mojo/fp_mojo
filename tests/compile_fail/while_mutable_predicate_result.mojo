# error: predicate must return Bool
from fp.control import while_loop_mut
from fp.callables import mut_ref
from while_predicate_support import Predicate, Body, Bare, Once, Both
def main():
    var body = Body(0)
    _ = while_loop_mut(Predicate(1,0),body,0)
