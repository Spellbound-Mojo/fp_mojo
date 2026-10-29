from fp.functions import pipeline
from fp.effects import delay, run_io, guarantee, canceled

def read_number() -> Int:
    print("read")
    return 21

def twice(value: Int) -> Int:
    return value * 2

def finish():
    print("finalize")

def main():
    var program = guarantee(pipeline(delay[Error](read_number)).map(twice).get(), delay[Error](finish))
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
