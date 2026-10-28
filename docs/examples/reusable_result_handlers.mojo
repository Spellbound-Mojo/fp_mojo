"""Reuse a borrowed predicate and observer across direct Result operations."""
from fp.functions import partial
from fp.data import err


def matches(expected: String, actual: String) -> Bool: return expected == actual
def replace(value: Int, error: String) -> Int: return value
def record(var prefix: String, error: String): print(prefix, error)


def main():
    var missing = partial(matches, String("missing"))
    var fallback = partial(replace, 0)
    var observer = partial(record, String("observed:"))
    var recovered = err[Int]("missing").tap_err(observer).recover_if(missing, fallback).get_or(-1)
    print("recovered:", recovered)
    var retained = err[Int]("fatal").tap_err(observer).recover_if(missing, fallback).swap().get_or("")
    print("retained:", retained)
