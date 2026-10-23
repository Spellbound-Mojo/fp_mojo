"""Accumulate at least one error while retaining a non-empty success shape."""
from fp.data import NonEmptyList, Result, Ok, Err
from fp.algebra import NonEmptyListFamily, NonEmptyListSemigroup, ValidationFamily, traverse
from fp.functions import piped

comptime Checked = Result[Int, NonEmptyList[String]]
comptime Errors = NonEmptyListSemigroup[String]

def positive(value: Int) -> Checked:
    if value <= 0:
        return Err(NonEmptyList(String(value) + " must be positive"))
    return Ok(value)

def total(a: Int, b: Int) -> Int: return a + b

def show_errors(var errors: NonEmptyList[String]) -> Int:
    print("errors:", len(errors))
    for error in errors^:
        print(error)
    return 0

def show_total(value: Int) -> Int:
    print("total:", value)
    return value

def show_values(var values: NonEmptyList[Int]) -> Int:
    print("first:", values.first(), "count:", len(values))
    return len(values)

def main():
    var checked = piped(positive(-1)).par_map_n[Errors]((positive(-2),), total).get()
    _ = checked^.fold_owned(show_total, show_errors)
    var values = NonEmptyList(2, List[Int]([3, 4]))
    var valid = traverse[NonEmptyListFamily, ValidationFamily[Errors]](positive, values^)
    _ = valid^.fold_owned(show_values, show_errors)
