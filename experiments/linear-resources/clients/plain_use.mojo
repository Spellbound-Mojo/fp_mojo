"""Control: an ordinary Int resource used once, without composition."""
from fp.effects import resource


def open_int() raises -> Int:
    return 1


def close_int(var i: Int) raises:
    print("  close", i)


def show_id(i: Int) -> String:
    return "id " + String(i)


def main():
    var used = resource[Error](open_int, close_int).use(show_id)
    if used.is_ok():
        print("use ok", used^._take_ok())
