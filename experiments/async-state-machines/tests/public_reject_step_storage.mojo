# error: no matching function in initialization
from fp.effects.async_runtime.protocols import Step, Wait


def main():
    _ = Step[Int, Int](None, Wait(), True)
