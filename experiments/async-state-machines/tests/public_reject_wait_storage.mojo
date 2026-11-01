# error: has no attribute 'interruptible'
from fp.effects.async_runtime.protocols import Wait


def main():
    var wait = Wait()
    wait.interruptible = False
