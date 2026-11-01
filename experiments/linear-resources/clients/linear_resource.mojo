"""A linear connection through the native resource scope: every exit releases it once."""
from fp.effects import linear_resource as resource, EffectFailure
from fp.data import Result


struct Conn(Movable, not Deinitable else "call 'close()'"):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def close(deinit self) raises:
        print("  close", self.id)
        if self.id == 3 or self.id == 4:
            raise Error("close failed " + String(self.id))


def open_1() raises -> Conn:
    print("  open 1")
    return Conn(1)


def open_2() raises -> Conn:
    print("  open 2")
    return Conn(2)


def open_3() raises -> Conn:
    print("  open 3")
    return Conn(3)


def open_4() raises -> Conn:
    print("  open 4")
    return Conn(4)


def open_fails() raises -> Conn:
    print("  open fails")
    raise Error("open failed")


def close(var c: Conn) raises:
    c^.close()


def query(c: Conn) raises -> Int:
    print("  query", c.id)
    if c.id == 2 or c.id == 4:
        raise Error("query failed " + String(c.id))
    return c.id * 100


def conn_id(c: Conn) -> Int:
    return c.id


def show_id(i: Int) -> String:
    return "id " + String(i)


def report(name: String, var result: Result[Int, EffectFailure[Error]]):
    if result.is_ok():
        print(name, "ok", result^._take_ok())
    else:
        var errors = result^._take_err().into_errors().into_list()
        var text = String()
        for error in errors:
            text += "[" + String(error) + "]"
        print(name, "err", text)


def main():
    print("success")
    report("success", resource[Error](open_1, close).use(query))
    print("use fails")
    report("use fails", resource[Error](open_2, close).use(query))
    print("release fails")
    report("release fails", resource[Error](open_3, close).use(query))
    print("both fail")
    report("both fail", resource[Error](open_4, close).use(query))
    print("acquire fails")
    report("acquire fails", resource[Error](open_fails, close).use(query))
