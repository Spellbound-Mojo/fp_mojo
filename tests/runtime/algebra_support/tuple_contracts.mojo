"""Generic attachment clients use public contracts without private adapters."""
from fp.algebra import Functor
from fp.algebra.contracts import TupleLeftContract, TupleRightContract
from fp.functions import Pipeline, pipeline


def attached_left[I: Functor, V: Movable & Deinitable, U: Movable & Deinitable](
    var source: V, var attachment: U
) raises TupleLeftContract[I, V, U].Error -> TupleLeftContract[I, V, U].Out where TupleLeftContract[I, V, U].InvocationCompatible:
    return pipeline[I](source^).tuple_left(attachment^).get()


def attached_right[I: Functor, V: Movable & Deinitable, U: Movable & Deinitable](
    var source: V, var attachment: U
) raises TupleRightContract[I, V, U].Error -> TupleRightContract[I, V, U].Out where TupleRightContract[I, V, U].InvocationCompatible:
    return pipeline[I](source^).tuple_right(attachment^).get()


def continued[I: Functor, V: Movable & Deinitable, U: Movable & Deinitable](
    var source: V, var attachment: U
) raises TupleLeftContract[I, V, U].Error -> Pipeline[TupleLeftContract[I, V, U].Family, TupleLeftContract[I, V, U].Out] where TupleLeftContract[I, V, U].InvocationCompatible:
    return pipeline[I](source^).tuple_left(attachment^)


def reattached[I: Functor, V: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable](
    var source: Pipeline[I, V, E], var attachment: U
) raises TupleRightContract[I, V, U].Error -> Pipeline[TupleRightContract[I, V, U].Family, TupleRightContract[I, V, U].Out, E] where TupleRightContract[I, V, U].InvocationCompatible:
    return source^.tuple_right(attachment^)
