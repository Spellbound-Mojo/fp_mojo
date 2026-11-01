# Mojo 1.2: bind C before checking the invalid native signature.
# Removing this hint reproduces a compiler crash; see native-boundaries.md.
# error: value passed to 'C' cannot be converted
# error: no matching
from fp.functions import pipeline
def consume(var value: String) -> Optional[Int]: return Optional(1)
def main():
    _ = pipeline(Optional(String('owned'))).flat_tap[C=type_of(consume)](consume)
