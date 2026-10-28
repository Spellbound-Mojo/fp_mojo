# error: constraint
from fp.effects.resources import resource

def acquire() -> Int: return 1
def release(var value: Int): pass
def main():
    _ = resource[Error](acquire, release).product(resource[String](acquire, release))
