# error: no matching method
from fp.functions import pipeline, partial

def scale(factor: Int, value: Int) -> Int: return factor * value
def main():
    var callback = partial(scale, 3)
    _ = pipeline(String("wrong")).then(callback).get()
