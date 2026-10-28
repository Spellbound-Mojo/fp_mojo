from fp.algebra import map
from fp.effects import IO, delay, run_io, guarantee, canceled

def read_number() -> Int:
    print("read")
    return 21

def twice(value: Int) -> Int:
    return value * 2

def finish():
    print("finalize")

def main():
    var program = guarantee(map[IO[Error]](twice, delay[Error](read_number)), delay[Error](finish))
    print("program ready")
    var outcome = run_io(program^)
    if outcome:
        var result = outcome.take()
        try:
            print("value:", result^.raise_on_err())
        except failure:
            print("errors:", len(failure.errors))
    var cancellation = run_io(guarantee(canceled[Error](), delay[Error](finish)))
    print("canceled:", not cancellation)
