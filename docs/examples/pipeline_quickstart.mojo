"""Start a fluent pipeline without adapters or explicit type arguments."""
from fp.functions import pipeline
from std.testing import assert_equal


def twice(value: Int) -> Int: return value * 2


def main() raises:
    var answer = pipeline(21).then(twice).get()
    assert_equal(answer, 42)
    print(answer)
