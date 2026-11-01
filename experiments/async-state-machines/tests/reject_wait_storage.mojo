# error: has no attribute 'interruptible'
from fp.effects._async.kernel import Wait


def main():
    var wait = Wait()
    wait.interruptible = False
