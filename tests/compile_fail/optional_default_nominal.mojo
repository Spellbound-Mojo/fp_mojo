# error: no matching
from fp.functions import pipeline
@fieldwise_init
struct Token(Movable):
    var value: Int
@fieldwise_init
struct Other(Movable):
    var value: Int
def factory() -> Other: return Other(7)
def main():
    _ = pipeline(Optional[Token]()).get_or_else(factory)
