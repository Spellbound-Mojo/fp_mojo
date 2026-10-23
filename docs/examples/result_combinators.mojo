"""Validate, bind, observe and recover in a direct Result chain."""
from fp.data import Result, Ok


def positive(value: Int) -> Bool:
    return value > 0


def invalid(value: Int) -> String:
    return "rejected " + String(value)


def double(value: Int) -> Result[Int, String]:
    return Ok(value * 2)


def record(value: Int) -> Result[Int, String]:
    print("checked:", value)
    return Ok(value + 1)


def log_error(error: String):
    print(error)


def fallback(var error: String) -> Int:
    return 0


def main() raises:
    for value in [4, -2]:
        var result = (
            Result[Int, String](Ok(value))
            .ensure(positive, invalid)
            .flat_map(double)
            .flat_tap(record)
            .tap_err(log_error)
            .recover(fallback)
        )
        print(result^.raise_on_err())
