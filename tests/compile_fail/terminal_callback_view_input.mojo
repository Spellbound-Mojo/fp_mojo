# error: no matching function
from fp.functions import partial
from fp.iteration import sum_by
def size(offset: Int, value: String) -> Int: return offset + value.byte_length()
def main():
    var project = partial(size, 1)
    _ = sum_by(range(3), project)
