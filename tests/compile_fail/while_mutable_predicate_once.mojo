# error: predicate must have a repeatable receiver
from fp.control import while_loop_mut
from fp.callables import mut_ref
from while_predicate_support import Predicate, Body, Bare, Once, Both
def main():
    var body = Body(0)
    _ = while_loop_mut(Once(),body,0)
