"""Relative conversion checks the supported range before native multiplication."""
from fp.effects._async.time import Duration
from std.os import abort


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def rejected(value: Int):
    var failures = 0
    try:
        _ = Duration.nanoseconds(value)
    except error:
        comptime assert type_of(error) == Error
        failures += 1
    try:
        _ = Duration.milliseconds(value)
    except error:
        comptime assert type_of(error) == Error
        failures += 1
    try:
        _ = Duration.seconds(value)
    except error:
        comptime assert type_of(error) == Error
        failures += 1
    check(failures == 3, "invalid counts must raise native setup Error in every unit")


def main() raises:
    check(Duration()._nanoseconds == 0, "default zero")
    check(Duration.nanoseconds(0)._nanoseconds == 0, "checked zero")
    check(Duration.milliseconds(42)._nanoseconds == 42000000, "exact millisecond conversion")
    check(Duration.seconds(42)._nanoseconds == 42000000000, "exact second conversion")
    comptime limit = 1000000000000000000
    check(Duration.nanoseconds(limit)._nanoseconds == limit, "maximum nanoseconds")
    check(Duration.milliseconds(limit // 1000000)._nanoseconds == limit, "maximum milliseconds")
    check(Duration.seconds(limit // 1000000000)._nanoseconds == limit, "maximum seconds")
    rejected(-1)
    rejected(Int.MIN)
    rejected(Int.MAX)
    rejected(limit + 1)
    var failures = 0
    try:
        _ = Duration.milliseconds(limit // 1000000 + 1)
    except:
        failures += 1
    try:
        _ = Duration.seconds(limit // 1000000000 + 1)
    except:
        failures += 1
    check(failures == 2, "scaled bounds reject just beyond the maximum")
    print("duration admission: zero, exact units, maximum bounds, negative and overflow rejection")
