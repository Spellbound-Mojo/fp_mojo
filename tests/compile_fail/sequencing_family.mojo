# error: Optional
from fp.functions import piped
def choices(value: Int) -> List[Int]: return List[Int]([value])
def main():
    _ = piped(Optional(1)).flat_tap(choices).get()
