"""Result compatibility imports and collection through shared algebra traversal.

Storage and branch transformations live in the lower-level _result module.
Algebra depends on that leaf; this user-facing adapter may depend on algebra.
"""
from ._result import Result, Ok, Err, attempt, attempt_once, raise_on_err
from fp.algebra.instances import ResultFamily
from fp.functions.composition import Identity
from std.builtin.rebind import rebind_var
from std.iter import Iterator


def collect_results[T: Movable & Deinitable, E: Movable & Deinitable,
                    I: Iterator](
    var source: I
) -> Result[List[T], E] where I.Element == Result[T, E]:
    """Collect the success values of a source of Results, or return the first `Err`.

    Pulling stops at the first `Err`; the collected prefix and the rest of an
    owned source are destroyed. It shares the collection loop of the algebra's
    `sequence` and `traverse`.

    Parameters:
        T: The success type.
        E: The stored error type.
        I: The source's type: a native iterator of `Result[T, E]`.

    Args:
        source: The source, consumed.

    Returns:
        `Ok` of a `List` of the values in order, or the first `Err`; `Ok` of an
        empty list for an empty source.
    """
    # Result's collection is the traversal loop with the identity callback.
    var collected = ResultFamily[E].collect(Identity[Result[T, E]](), source^)
    return rebind_var[Result[List[T], E]](collected^)
