"""Collect independent errors with the same Result type used for dependent steps."""
from fp.data import Result, Ok, Err
from fp.functions import pipeline, kleisli
from fp.iteration import iterated
from fp.algebra import ResultFamily

comptime Checked = Result[Int, List[String]]


def positive(value: Int) -> Checked:
    if value <= 0:
        var errors: List[String] = [String(value) + " must be positive"]
        return Err(errors^)
    return Ok(value)


def total(a: Int, b: Int, c: Int) -> Int: return a + b + c
def squared(value: Int) -> Int: return value * value

def show_total(value: Int) -> String: return "total: " + String(value)
def show_values(var values: List[Int]) -> String:
    var text = String("values:")
    for value in values:
        text += " " + String(value)
    return text^

def show_errors(var errors: List[String]) -> String:
    var text = String("errors:")
    for error in errors:
        text += " " + error + ";"
    return text^


def main():
    var valid = pipeline(positive(2)).par_map_n((positive(3), positive(4)), total).get()
    print(valid^.fold_owned(show_total, show_errors))
    var invalid = pipeline(positive(-2)).par_map_n((positive(3), positive(-4)), total).get()
    print(invalid^.fold_owned(show_total, show_errors))

    var check = kleisli[ResultFamily[List[String]]](positive).map(squared)
    var eager = pipeline(List[Int]([2, -3, 4, -5])).par_traverse(check).get()
    print(eager^.fold_owned(show_values, show_errors))
    var collected = iterated(range(1, 4)).par_traverse(check)
    print(collected^.fold_owned(show_values, show_errors))

    var pair = pipeline(positive(2)).par_product_n((positive(3),)).get()
    print("pair:", pair._ok().value[0], pair._ok().value[1])
    var checks: List[Checked] = [positive(2), positive(-3), positive(-4)]
    var sequenced = pipeline(checks^).par_sequence().get()
    print(sequenced^.fold_owned(show_values, show_errors))
