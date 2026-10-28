"""Keep an owned native closure reusable as a library callable."""
from fp.functions import pipeline, as_unary, as_binary
from fp.iteration import iterated


def add(var first: Int, var second: Int) -> Int: return first + second


def main():
    var prefix = String("item-")
    def label(var value: Int) {var prefix^} -> String:
        return prefix + String(value)
    var formatter = as_unary(label^)
    print("first:", pipeline(Optional(2)).map(formatter).get_or(""))
    print("again:", pipeline(3).then(formatter).get())
    print("moved:", pipeline(4).then(formatter^).get())
    var combine = as_binary(add)
    print("running:", iterated(range(1, 4)).scan_left(combine, 0).collect_list())
    print("zipped:", iterated(range(2)).zip_with(range(3, 5), combine).collect_list())
