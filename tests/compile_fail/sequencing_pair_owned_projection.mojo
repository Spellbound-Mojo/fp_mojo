# error: no matching
from fp.functions import piped
def consume(var value: String) -> Optional[Int]: return Optional(1)
def main():
    _ = piped(Optional(String('owned'))).flat_pair_with(consume)
