"""Control for linear_projection.mojo: the same chain over an ordinary Int resource."""
from fp.effects import resource


def open_int() raises -> Int:
    print("  open 1")
    return 1


def close_int(var i: Int) raises:
    print("  close", i)


def int_id(i: Int) -> Int:
    return i


def show_id(i: Int) -> String:
    return "id " + String(i)


def main():
    var projected = resource[Error](open_int, close_int).map(int_id).use(show_id)
    if projected.is_ok():
        print("projection ok", projected^._take_ok())
