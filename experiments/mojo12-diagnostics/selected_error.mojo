# The same invalid convention with the error type fixed before inference.
# Mojo 1.2.0 (2016d0cd) emits a normal cannot-be-converted diagnostic.
def accept[A: Movable & Deinitable, R: Movable & Deinitable,
           //, F: def(A) raises Int -> R](function: F):
    pass

def callback(var value: Int) -> Bool:
    return value > 0

def main():
    accept(callback)
