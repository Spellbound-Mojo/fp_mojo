# error: Optional
from fp.functions import pipeline
def choices(value: Int) -> List[Int]: return List[Int]([value])
def main():
    _ = pipeline(Optional(1)).flat_tap(choices).get()
