# error: value passed to 'error' cannot be converted from 'String' to 'Async[Int].Error'
from fp.effects import raise_error
from fp.effects.async_runtime import Async


def main():
    _ = raise_error[Async[Int], Int](String("not an Int"))
