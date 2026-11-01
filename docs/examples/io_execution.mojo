from fp.functions import pipeline
from fp.effects import delay, canceled

def read_number() -> Int:
    print("read")
    return 21

def twice(value: Int) -> Int:
    return value * 2

def finish():
    print("finalize")

def main():
    var program = pipeline(delay[Error](read_number)).map(twice).guarantee(delay[Error](finish))
    print("program ready")
    var outcome = program^.run_io()
    if outcome:
        var result = outcome.take()
        try:
            print("value:", result^.raise_on_err())
        except failure:
            print("errors:", len(failure.errors))
    var cancellation = pipeline(canceled[Error]()).guarantee(delay[Error](finish)).run_io()
    print("canceled:", not cancellation)
