# error: uninitialized
from fp.effects.resources import resource

def acquire() -> Int: return 1
def release(var value: Int): pass
def use(value: Int) -> Int: return value
def main():
    var scope = resource[Error](acquire, release)
    _ = scope^.use(use)
    _ = scope^.use(use)
