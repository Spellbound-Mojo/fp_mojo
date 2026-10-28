# error: aliasing
from fp.control import while_loop_mut
from fp.callables import mut_ref
from while_predicate_support import Predicate, Body, Bare, Once, Both
def main():
    var state = Both(0)
    _ = while_loop_mut(mut_ref(state),state,0)
