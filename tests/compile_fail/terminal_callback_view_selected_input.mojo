# error: no matching method
from fp.functions import partial, pipeline
def size(offset: Int, value: String) -> Int: return offset + value.byte_length()
def main():
    var project = partial(size, 1)
    _ = pipeline(range(3)).sum_by(project).get()
