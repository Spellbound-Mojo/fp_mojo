# error: constraint failed: while loop: incompatible errors
from fp.control import while_loop_mut
from while_predicate_support import Predicate, Body

def main():
    var body = Body[String](0)
    try:
        _ = while_loop_mut(Predicate[Bool,Int](False,0),body,0)
    except _: pass
