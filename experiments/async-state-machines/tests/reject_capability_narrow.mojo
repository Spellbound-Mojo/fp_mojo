# error: no matching function in call to 'canceled'
from fp.effects import canceled
from capability_family import DeferOnly


def main():
    _ = canceled[DeferOnly[Int]]()
