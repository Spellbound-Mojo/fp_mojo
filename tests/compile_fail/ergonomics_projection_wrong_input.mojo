# error: no matching
from fp.effects import Reader, asks
def text_size(value: String) -> Int: return value.byte_length()
def main(): _ = asks[Reader[Int]](text_size)
