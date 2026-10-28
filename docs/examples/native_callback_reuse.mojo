"""Keep an owned native closure reusable as a library callable."""
from fp.functions import pipeline, as_unary


def main():
    var prefix = String("item-")
    def label(var value: Int) {var prefix^} -> String:
        return prefix + String(value)
    var formatter = as_unary(label^)
    print("first:", pipeline(Optional(2)).map(formatter).get_or(""))
    print("again:", pipeline(3).then(formatter).get())
    print("moved:", pipeline(4).then(formatter^).get())
